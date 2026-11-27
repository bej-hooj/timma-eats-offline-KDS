#include "tv_surface.h"

#include <cwchar>

namespace tv_surface {

namespace {

struct MonitorSearch {
  bool found_secondary = false;
  RECT secondary{};
  RECT primary{};
};

BOOL CALLBACK CollectMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* search = reinterpret_cast<MonitorSearch*>(data);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, &info)) {
    return TRUE;
  }
  if (info.dwFlags & MONITORINFOF_PRIMARY) {
    search->primary = info.rcMonitor;
  } else if (!search->found_secondary) {
    search->found_secondary = true;
    search->secondary = info.rcMonitor;
  }
  return TRUE;
}

}  // namespace

bool IsTvSurface(const wchar_t* command_line) {
  return command_line != nullptr &&
         std::wcsstr(command_line, kTvSurfaceFlag) != nullptr;
}

RECT TargetMonitorRect() {
  MonitorSearch search;
  EnumDisplayMonitors(nullptr, nullptr, CollectMonitor,
                      reinterpret_cast<LPARAM>(&search));
  return search.found_secondary ? search.secondary : search.primary;
}

void FillTargetMonitor(HWND window) {
  if (window == nullptr) {
    return;
  }
  const RECT r = TargetMonitorRect();
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
