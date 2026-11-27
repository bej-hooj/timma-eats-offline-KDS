#ifndef RUNNER_TV_SPEECH_CHANNEL_H_
#define RUNNER_TV_SPEECH_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include "tv_surface.h"

#include <condition_variable>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

// The TV's voice (S6). Dart side: lib/tv/data/windows_tv_speech.dart.
//
// Why native: Windows sends every app's sound to ONE default device and keys
// its per-app routing by exe path — the kitchen board and the TV are the same
// exe, so Windows cannot send one to the PC speakers and the other to the TV.
// Here the TV synthesizes speech with WinRT SpeechSynthesizer and plays it
// through a MediaPlayer whose AudioDevice is the output the manager chose
// (the LG TV over HDMI). The kitchen alarm keeps the default device.
//
// Methods (all answered on the platform thread):
//   listOutputs -> [{id, name, isDefault}]
//   listVoices  -> [{id, name, language}]
//   say {text: String, chime: bool, outputId: String?, voiceId: String?}
//               -> null once played (one utterance at a time, in order)
//   listMonitors   -> [{id, name, isPrimary, width, height}]   (S6-B)
//   placeOnMonitor {id: String?} -> null (window moved; null = default)
//   playSound {asset: "kds_waiting.wav", outputId: String?} -> null when done
//   stopSound      -> null (cuts the clip playing now)
class TvSpeechChannel {
 public:
  // Keep identical to WindowsTvSpeech.channelName.
  static constexpr const char kChannelName[] = "timma/tv_speech";

  // Posted to |window| when a job finishes; FlutterWindow forwards it to
  // Deliver(). WPARAM = job id.
  static constexpr UINT kDoneMessage = WM_APP + 0x54;

  TvSpeechChannel(flutter::BinaryMessenger* messenger, HWND window,
                  tv_surface::Surface surface);
  ~TvSpeechChannel();

  TvSpeechChannel(const TvSpeechChannel&) = delete;
  TvSpeechChannel& operator=(const TvSpeechChannel&) = delete;

  // Completes job |id| on the platform thread.
  void Deliver(WPARAM id);

 private:
  using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

  struct Outcome {
    bool ok = true;
    flutter::EncodableValue value;
    std::string error_code;
  };

  void HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                  Result result);
  void Enqueue(Result result, std::function<Outcome()> job);
  void WorkerLoop();

  HWND window_;
  tv_surface::Surface surface_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  std::mutex mutex_;
  std::condition_variable wake_;
  std::deque<std::pair<WPARAM, std::function<Outcome()>>> jobs_;
  std::map<WPARAM, Result> waiting_;
  std::map<WPARAM, Outcome> finished_;
  WPARAM next_id_ = 1;
  bool stopping_ = false;
  std::thread worker_;
};

#endif  // RUNNER_TV_SPEECH_CHANNEL_H_
