#include "tv_speech_channel.h"

#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>
#include <winrt/Windows.Media.Devices.h>
#include <winrt/Windows.Media.Playback.h>
#include <winrt/Windows.Media.SpeechSynthesis.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

#include <atomic>
#include <chrono>
#include <regex>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace wde = winrt::Windows::Devices::Enumeration;
namespace wmc = winrt::Windows::Media::Core;
namespace wmd = winrt::Windows::Media::Devices;
namespace wmp = winrt::Windows::Media::Playback;
namespace wms = winrt::Windows::Media::SpeechSynthesis;
namespace wst = winrt::Windows::Storage;

// The longest text accepted (bytes of UTF-8). The app caps at 500 characters;
// this is the native belt to its braces.
constexpr size_t kMaxTextBytes = 2000;

// The longest a single clip may play before we give up on it.
constexpr auto kPlayTimeout = std::chrono::seconds(30);

// Relative to the exe: the chime the kitchen board also ships.
constexpr const wchar_t kChimeRelative[] =
    L"data\\flutter_assets\\assets\\audio\\kds_notice.wav";

const std::string* StringArg(const EncodableMap& args, const char* key) {
  auto it = args.find(EncodableValue(key));
  if (it == args.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&it->second);
}

// The speaking rate the app asked for, clamped to what the synthesizer takes.
double RateArg(const EncodableMap& args) {
  auto it = args.find(EncodableValue("rate"));
  if (it == args.end()) {
    return 1.0;
  }
  const double* value = std::get_if<double>(&it->second);
  if (value == nullptr) {
    return 1.0;
  }
  return *value < 0.5 ? 0.5 : (*value > 1.5 ? 1.5 : *value);
}

bool BoolArg(const EncodableMap& args, const char* key) {
  auto it = args.find(EncodableValue(key));
  if (it == args.end()) {
    return false;
  }
  const bool* value = std::get_if<bool>(&it->second);
  return value != nullptr && *value;
}

std::wstring ExeDirectory() {
  wchar_t path[MAX_PATH];
  const DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring full(path, n);
  const size_t slash = full.find_last_of(L"\\/");
  return slash == std::wstring::npos ? L"" : full.substr(0, slash + 1);
}

// The device the manager chose, or null (= Windows default) when the id is
// empty or no longer exists (the TV unplugged).
wde::DeviceInformation FindOutput(const std::string* id) {
  if (id == nullptr || id->empty()) {
    return nullptr;
  }
  try {
    return wde::DeviceInformation::CreateFromIdAsync(winrt::to_hstring(*id))
        .get();
  } catch (...) {
    return nullptr;
  }
}

std::atomic<bool> g_stopping{false};

// Set by stopSound: the clip playing now ends at the next 100 ms check.
std::atomic<bool> g_cut_clip{false};

// playSound accepts a bare lowercase file name ending in .wav — nothing that
// could climb out of assets/audio (path-traversal guard).
bool IsSafeAssetName(const std::string& name) {
  static const std::regex kSafe("^[a-z_]{1,40}\\.wav$");
  return std::regex_match(name, kSafe);
}

// A human name for a monitor ("LG TV", "Generic PnP Monitor"); falls back to
// the device name.
std::string FriendlyMonitorName(const std::wstring& device) {
  DISPLAY_DEVICEW dd{};
  dd.cb = sizeof(dd);
  if (EnumDisplayDevicesW(device.c_str(), 0, &dd, 0) && dd.DeviceString[0]) {
    return winrt::to_string(dd.DeviceString);
  }
  return winrt::to_string(device);
}


// Plays |source| to the end (or the timeout) on |device|.
bool Play(const wmc::MediaSource& source, const wde::DeviceInformation& device,
          const std::atomic<bool>& stopping) {
  wmp::MediaPlayer player;
  player.AutoPlay(false);
  if (device != nullptr) {
    player.AudioDevice(device);
  }
  HANDLE done = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (done == nullptr) {
    return false;
  }
  std::atomic<bool> ok{true};
  {
    auto ended = player.MediaEnded(
        winrt::auto_revoke, [done](auto&&, auto&&) { SetEvent(done); });
    auto failed = player.MediaFailed(
        winrt::auto_revoke, [done, &ok](auto&&, auto&&) {
          ok.store(false);
          SetEvent(done);
        });
    player.Source(source);
    player.Play();
    const auto deadline = std::chrono::steady_clock::now() + kPlayTimeout;
    // Short waits, so a closing app is never held for the full timeout.
    while (WaitForSingleObject(done, 100) == WAIT_TIMEOUT) {
      if (stopping.load() || g_cut_clip.load() ||
          std::chrono::steady_clock::now() > deadline) {
        ok.store(false);
        break;
      }
    }
  }
  player.Close();
  CloseHandle(done);
  return ok.load();
}

wms::VoiceInformation PickVoice(const std::string* id) {
  const auto voices = wms::SpeechSynthesizer::AllVoices();
  if (id != nullptr && !id->empty()) {
    const winrt::hstring wanted = winrt::to_hstring(*id);
    for (const auto& v : voices) {
      if (v.Id() == wanted) {
        return v;
      }
    }
  }
  // Default: a French WOMAN's voice (owner, 2026-11-27) — Hortense / Julie on
  // a French Windows; any French voice if no female one is installed.
  wms::VoiceInformation any_french = nullptr;
  for (const auto& v : voices) {
    const std::wstring lang(v.Language().c_str());
    if (lang.rfind(L"fr", 0) != 0) {
      continue;
    }
    if (v.Gender() == wms::VoiceGender::Female) {
      return v;
    }
    if (any_french == nullptr) {
      any_french = v;
    }
  }
  return any_french;
}

}  // namespace

TvSpeechChannel::TvSpeechChannel(flutter::BinaryMessenger* messenger,
                                 HWND window, tv_surface::Surface surface)
    : window_(window), surface_(surface) {
  g_stopping.store(false);
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call, Result result) {
        HandleCall(call, std::move(result));
      });
  worker_ = std::thread([this] { WorkerLoop(); });
}

TvSpeechChannel::~TvSpeechChannel() {
  channel_->SetMethodCallHandler(nullptr);
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stopping_ = true;
    g_stopping.store(true);
  }
  wake_.notify_all();
  if (worker_.joinable()) {
    worker_.join();
  }
}

void TvSpeechChannel::HandleCall(
    const flutter::MethodCall<EncodableValue>& call, Result result) {
  const std::string& method = call.method_name();

  if (method == "listOutputs") {
    Enqueue(std::move(result), [] {
      Outcome out;
      EncodableList rows;
      const winrt::hstring default_id =
          wmd::MediaDevice::GetDefaultAudioRenderId(
              wmd::AudioDeviceRole::Default);
      const auto devices = wde::DeviceInformation::FindAllAsync(
                               wmd::MediaDevice::GetAudioRenderSelector())
                               .get();
      for (const auto& d : devices) {
        rows.push_back(EncodableValue(EncodableMap{
            {EncodableValue("id"), EncodableValue(winrt::to_string(d.Id()))},
            {EncodableValue("name"),
             EncodableValue(winrt::to_string(d.Name()))},
            {EncodableValue("isDefault"), EncodableValue(d.Id() == default_id)},
        }));
      }
      out.value = EncodableValue(rows);
      return out;
    });
    return;
  }

  if (method == "listVoices") {
    Enqueue(std::move(result), [] {
      Outcome out;
      EncodableList rows;
      for (const auto& v : wms::SpeechSynthesizer::AllVoices()) {
        rows.push_back(EncodableValue(EncodableMap{
            {EncodableValue("id"), EncodableValue(winrt::to_string(v.Id()))},
            {EncodableValue("name"),
             EncodableValue(winrt::to_string(v.DisplayName()))},
            {EncodableValue("language"),
             EncodableValue(winrt::to_string(v.Language()))},
        }));
      }
      out.value = EncodableValue(rows);
      return out;
    });
    return;
  }

  if (method == "say") {
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    const std::string* text = args ? StringArg(*args, "text") : nullptr;
    if (text == nullptr || text->empty() || text->size() > kMaxTextBytes) {
      result->Error("bad_args", "text missing or too long");
      return;
    }
    const std::string text_copy = *text;
    const bool chime = BoolArg(*args, "chime");
    const std::string* output = StringArg(*args, "outputId");
    const std::string* voice = StringArg(*args, "voiceId");
    const std::string output_copy = output ? *output : "";
    const std::string voice_copy = voice ? *voice : "";
    const double rate = RateArg(*args);
    Enqueue(std::move(result), [text_copy, chime, output_copy, voice_copy,
                                rate] {
      Outcome out;
      // A stopSound aimed at an earlier clip must not cut this utterance.
      g_cut_clip.store(false);
      const wde::DeviceInformation device = FindOutput(&output_copy);
      if (chime) {
        try {
          const auto file = wst::StorageFile::GetFileFromPathAsync(
                                ExeDirectory() + kChimeRelative)
                                .get();
          Play(wmc::MediaSource::CreateFromStorageFile(file), device,
               g_stopping);
        } catch (...) {
          // A missing chime must not cost the announcement.
        }
      }
      wms::SpeechSynthesizer synth;
      const wms::VoiceInformation picked = PickVoice(&voice_copy);
      if (picked != nullptr) {
        synth.Voice(picked);
      }
      // Slower than normal so a ticket code is understood in a noisy room.
      synth.Options().SpeakingRate(rate);
      const auto stream =
          synth.SynthesizeTextToStreamAsync(winrt::to_hstring(text_copy))
              .get();
      if (!Play(wmc::MediaSource::CreateFromStream(stream,
                                                   stream.ContentType()),
                device, g_stopping)) {
        out.ok = false;
        out.error_code = "play_failed";
      }
      return out;
    });
    return;
  }

  if (method == "listMonitors") {
    // Win32 only, no WinRT: answered here on the platform thread.
    EncodableList rows;
    for (const tv_surface::MonitorInfo& m : tv_surface::ListMonitors()) {
      rows.push_back(EncodableValue(EncodableMap{
          {EncodableValue("id"), EncodableValue(winrt::to_string(m.device))},
          {EncodableValue("name"), EncodableValue(FriendlyMonitorName(m.device))},
          {EncodableValue("isPrimary"), EncodableValue(m.primary)},
          {EncodableValue("width"),
           EncodableValue(static_cast<int>(m.rect.right - m.rect.left))},
          {EncodableValue("height"),
           EncodableValue(static_cast<int>(m.rect.bottom - m.rect.top))},
      }));
    }
    result->Success(EncodableValue(rows));
    return;
  }

  if (method == "placeOnMonitor") {
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    const std::string* id = args ? StringArg(*args, "id") : nullptr;
    // Unknown or empty id = the surface's default (TargetMonitorRect).
    tv_surface::SetPreferredMonitor(id ? winrt::to_hstring(*id).c_str()
                                       : std::wstring());
    tv_surface::FillTargetMonitor(window_, surface_);
    result->Success();
    return;
  }

  if (method == "stopSound") {
    g_cut_clip.store(true);
    result->Success();
    return;
  }

  if (method == "playSound") {
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    const std::string* asset = args ? StringArg(*args, "asset") : nullptr;
    if (asset == nullptr || !IsSafeAssetName(*asset)) {
      result->Error("bad_args", "asset must be a bare .wav name");
      return;
    }
    const std::wstring file =
        std::wstring(L"data\\flutter_assets\\assets\\audio\\") +
        std::wstring(winrt::to_hstring(*asset).c_str());
    const std::string* output = StringArg(*args, "outputId");
    const std::string output_copy = output ? *output : "";
    Enqueue(std::move(result), [file, output_copy] {
      Outcome out;
      g_cut_clip.store(false);
      const wde::DeviceInformation device = FindOutput(&output_copy);
      const auto storage =
          wst::StorageFile::GetFileFromPathAsync(ExeDirectory() + file).get();
      Play(wmc::MediaSource::CreateFromStorageFile(storage), device,
           g_stopping);
      return out;
    });
    return;
  }

  result->NotImplemented();
}

void TvSpeechChannel::Enqueue(Result result, std::function<Outcome()> job) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    const WPARAM id = next_id_++;
    waiting_[id] = std::move(result);
    jobs_.emplace_back(id, std::move(job));
  }
  wake_.notify_one();
}

void TvSpeechChannel::WorkerLoop() {
  // WinRT async calls are waited on with .get(), which is only legal off an
  // STA: this thread joins the multi-threaded apartment.
  winrt::init_apartment(winrt::apartment_type::multi_threaded);
  for (;;) {
    std::pair<WPARAM, std::function<Outcome()>> next;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      wake_.wait(lock, [this] { return stopping_ || !jobs_.empty(); });
      if (stopping_) {
        break;
      }
      next = std::move(jobs_.front());
      jobs_.pop_front();
    }
    Outcome outcome;
    try {
      outcome = next.second();
    } catch (const winrt::hresult_error&) {
      outcome.ok = false;
      outcome.error_code = "speech_failed";
    } catch (...) {
      outcome.ok = false;
      outcome.error_code = "speech_failed";
    }
    {
      std::lock_guard<std::mutex> lock(mutex_);
      finished_[next.first] = std::move(outcome);
    }
    PostMessageW(window_, kDoneMessage, next.first, 0);
  }
  winrt::uninit_apartment();
}

void TvSpeechChannel::Deliver(WPARAM id) {
  Result result;
  Outcome outcome;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto r = waiting_.find(id);
    auto o = finished_.find(id);
    if (r == waiting_.end() || o == finished_.end()) {
      return;
    }
    result = std::move(r->second);
    outcome = std::move(o->second);
    waiting_.erase(r);
    finished_.erase(o);
  }
  if (outcome.ok) {
    result->Success(outcome.value);
  } else {
    // A short code only — never the spoken text.
    result->Error(outcome.error_code);
  }
}
