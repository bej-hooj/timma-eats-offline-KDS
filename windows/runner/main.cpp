#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "tv_surface.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Kitchen board, Écran salle or Écran cuisine (S6 / S6-B). Dart parses the
  // same argument.
  const tv_surface::Surface surface = tv_surface::ParseSurface(command_line);
  const bool display = tv_surface::IsDisplay(surface);
  const wchar_t* title = tv_surface::TitleFor(surface);

  // One process per surface: a second launch focuses the open window instead
  // of starting a second writer on the same store. The handle is held for the
  // life of the process and released by Windows on exit.
  HANDLE instance_mutex = ::CreateMutexW(
      nullptr, TRUE, tv_surface::MutexFor(surface));
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND open = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", title);
    if (open != nullptr) {
      ::ShowWindow(open, SW_RESTORE);
      ::SetForegroundWindow(open);
    }
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, surface);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  // ⚠ The title a cook sees on the taskbar, and a window big enough to be a
  // board rather than a dialog. The lanes are laid out for a landscape
  // screen; 1280x800 is the smallest shape they were designed against.
  if (!window.Create(title, origin, size)) {
    return EXIT_FAILURE;
  }
  if (display) {
    // Borderless, over the whole TV (its non-primary monitor), never asleep.
    tv_surface::FillTargetMonitor(window.GetHandle(), surface);
    tv_surface::KeepDisplayAwake();
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
