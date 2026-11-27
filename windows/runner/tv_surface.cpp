#include "tv_surface.h"

#include <algorithm>
#include <cwchar>

namespace tv_surface {

namespace {

std::wstring g_preferred;

BOOL CALLBACK CollectMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* list = reinterpret_cast<std::vector<MonitorInfo>*>(data);
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, &info)) {
    return TRUE;
  }
  MonitorInfo m;
  m.device = info.szDevice;
  m.primary = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
  m.rect = info.rcMonitor;
  list->push_back(m);
  return TRUE;
}

// An exact token match: "--surface=tv" must not match inside another flag.
bool HasFlag(const wchar_t* command_line, const wchar_t* flag) {
  if (command_line == nullptr) {
    return false;
  }
  const size_t len = std::wcslen(flag);
  for (const wchar_t* p = std::wcsstr(command_line, flag); p != nullptr;
       p = std::wcsstr(p + 1, flag)) {
    const bool starts = p == command_line || p[-1] == L' ' || p[-1] == L'"';
    const wchar_t end = p[len];
    const bool ends = end == L'\0' || end == L' ' || end == L'"';
    if (starts && ends) {
      return true;
    }
  }
  return false;
}

}  // namespace

Surface ParseSurface(const wchar_t* command_line) {
  if (HasFlag(command_line, kTvSurfaceFlag)) {
    return Surface::kTv;
  }
  if (HasFlag(command_line, kKitchenTvSurfaceFlag)) {
    return Surface::kKitchenTv;
  }
  return Surface::kKitchen;
}

bool IsDisplay(Surface surface) { return surface != Surface::kKitchen; }

const wchar_t* TitleFor(Surface surface) {
  switch (surface) {
    case Surface::kTv:
      return kTvTitle;
    case Surface::kKitchenTv:
      return kKitchenTvTitle;
    default:
      return kKitchenTitle;
  }
}

const wchar_t* MutexFor(Surface surface) {
  switch (surface) {
    case Surface::kTv:
      return kTvMutex;
    case Surface::kKitchenTv:
      return kKitchenTvMutex;
    default:
      return kKitchenMutex;
  }
}

std::vector<MonitorInfo> ListMonitors() {
  std::vector<MonitorInfo> list;
  EnumDisplayMonitors(nullptr, nullptr, CollectMonitor,
                      reinterpret_cast<LPARAM>(&list));
  std::sort(list.begin(), list.end(),
            [](const MonitorInfo& a, const MonitorInfo& b) {
              return a.rect.left < b.rect.left;
            });
  return list;
}

void SetPreferredMonitor(const std::wstring& device) { g_preferred = device; }

RECT TargetMonitorRect(Surface surface) {
  const std::vector<MonitorInfo> list = ListMonitors();
  RECT primary{};
  std::vector<const MonitorInfo*> secondary;
  for (const MonitorInfo& m : list) {
    if (!g_preferred.empty() && m.device == g_preferred) {
      return m.rect;
    }
    if (m.primary) {
      primary = m.rect;
    } else {
      secondary.push_back(&m);
    }
  }
  if (secondary.empty()) {
    return primary;
  }
  return surface == Surface::kKitchenTv ? secondary.back()->rect
                                        : secondary.front()->rect;
}

void FillTargetMonitor(HWND window, Surface surface) {
  if (window == nullptr || !IsDisplay(surface)) {
    return;
  }
  const RECT r = TargetMonitorRect(surface);
  if (r.right <= r.left || r.bottom <= r.top) {
    return;
  }
  // WS_POPUP: no title bar, no border — the whole TV is the board.
  SetWindowLongPtrW(window, GWL_STYLE, WS_POPUP | WS_VISIBLE);
  SetWindowPos(window, HWND_TOP, r.left, r.top, r.right - r.left,
               r.bottom - r.top, SWP_FRAMECHANGED | SWP_NOACTIVATE);
}

void KeepDisplayAwake() {
  SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED |
                          ES_SYSTEM_REQUIRED);
}

}  // namespace tv_surface
