#ifndef RUNNER_TV_SURFACE_H_
#define RUNNER_TV_SURFACE_H_

#include <windows.h>

#include <string>
#include <vector>

// The display surfaces of timma_kds.exe (S6 / S6-B):
//   (no flag)              kitchen board on the laptop screen
//   --surface=tv           « Écran salle »  — docs/tv-salle-windows-hdmi-2026-11-27.md
//   --surface=kitchen-tv   « Écran cuisine » — docs/ecran-cuisine-tv-vga-2026-11-27.md
// Keep the flags identical to KdsSurfaceArgs in lib/launch/kds_surface.dart.
namespace tv_surface {

enum class Surface { kKitchen, kTv, kKitchenTv };

constexpr const wchar_t kTvSurfaceFlag[] = L"--surface=tv";
constexpr const wchar_t kKitchenTvSurfaceFlag[] = L"--surface=kitchen-tv";

// One instance per surface. A second double-click on an icon focuses the
// window already open instead of starting a second process on the same SQLite
// store.
constexpr const wchar_t kKitchenMutex[] = L"Local\\TIMMA-KDS-kitchen";
constexpr const wchar_t kTvMutex[] = L"Local\\TIMMA-KDS-tv";
constexpr const wchar_t kKitchenTvMutex[] = L"Local\\TIMMA-KDS-kitchen-tv";

// Window titles. \u00C9 = "É" (no reliance on the source file encoding).
constexpr const wchar_t kKitchenTitle[] = L"TIMMA Cuisine";
constexpr const wchar_t kTvTitle[] = L"TIMMA \u00C9cran salle";
constexpr const wchar_t kKitchenTvTitle[] = L"TIMMA \u00C9cran cuisine";

// One screen Windows drives.
struct MonitorInfo {
  std::wstring device;  // "\\.\DISPLAY2" — the id the app stores
  bool primary = false;
  RECT rect{};
};

// Which surface |command_line| asks for. Exact flags only; anything else is
// the kitchen board.
Surface ParseSurface(const wchar_t* command_line);

// True for a screen nobody touches (TV): full-screen, kept awake, native
// window/sound channel.
bool IsDisplay(Surface surface);

const wchar_t* TitleFor(Surface surface);
const wchar_t* MutexFor(Surface surface);

// Every monitor, sorted left to right.
std::vector<MonitorInfo> ListMonitors();

// The monitor the manager chose (F2 → « Écran »); empty = the default.
void SetPreferredMonitor(const std::wstring& device);

// The rectangle (physical pixels) this surface covers: the preferred monitor
// when it is still connected, else the default — Écran salle: FIRST
// non-primary monitor; Écran cuisine: LAST non-primary — so laptop + HDMI +
// VGA never put both TVs on one screen. Falls back to the primary monitor.
RECT TargetMonitorRect(Surface surface);

// Turns |window| into a borderless window covering the surface's monitor. Safe
// to call again (TV switched on later, DPI or resolution change, new choice).
void FillTargetMonitor(HWND window, Surface surface);

// Keeps the screen and the PC awake while this process runs.
void KeepDisplayAwake();

}  // namespace tv_surface

#endif  // RUNNER_TV_SURFACE_H_
