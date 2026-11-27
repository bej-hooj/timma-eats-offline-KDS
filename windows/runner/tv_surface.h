#ifndef RUNNER_TV_SURFACE_H_
#define RUNNER_TV_SURFACE_H_

#include <windows.h>

// The dining-room TV surface (S6, docs/tv-salle-windows-hdmi-2026-11-27.md).
//
// The same timma_kds.exe runs twice on the kitchen PC: once as the kitchen
// board, once with kTvSurfaceFlag as the customer display on the LG TV that is
// plugged in by HDMI as an extended screen. Keep kTvSurfaceFlag identical to
// KdsSurfaceArgs.tvFlag in lib/launch/kds_surface.dart.
namespace tv_surface {

constexpr const wchar_t kTvSurfaceFlag[] = L"--surface=tv";

// One instance per surface. A second double-click on an icon focuses the
// window already open instead of starting a second process on the same SQLite
// store.
constexpr const wchar_t kKitchenMutex[] = L"Local\\TIMMA-KDS-kitchen";
constexpr const wchar_t kTvMutex[] = L"Local\\TIMMA-KDS-tv";

// Window titles. É = "É" (no reliance on the source file encoding).
constexpr const wchar_t kKitchenTitle[] = L"TIMMA Cuisine";
constexpr const wchar_t kTvTitle[] = L"TIMMA Écran salle";

// True when |command_line| asks for the TV surface.
bool IsTvSurface(const wchar_t* command_line);

// The rectangle (physical pixels) of the first monitor that is NOT the primary
// one — the TV in "Extend" mode. Falls back to the primary monitor when only
// one screen is connected, so the owner still sees the window.
RECT TargetMonitorRect();

// Turns |window| into a borderless window covering the target monitor. Safe to
// call again (the TV switched on after the PC, a DPI change, a resolution
// change).
void FillTargetMonitor(HWND window);

// Keeps the screen and the PC awake while this process runs.
void KeepDisplayAwake();

}  // namespace tv_surface

#endif  // RUNNER_TV_SURFACE_H_
