#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "tv_surface.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Kitchen board or dining-room TV (S6). Dart parses the same argument.
  const bool tv = tv_surface::IsTvSurface(command_line);
  const wchar_t* title = tv ? tv_surface::kTvTitle : tv_surface::kKitchenTitle;

  // One process per surface: a second launch focuses the open window instead
  // of starting a second writer on the same store. The handle is held for the
  // life of the process and released by Windows on exit.
  HANDLE instance_mutex = ::CreateMutexW(
      nullptr, TRUE, tv ? tv_surface::kTvMutex : tv_surface::kKitchenMutex);
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

  FlutterWindow window(project, tv);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  // ⚠ The title a cook sees on the taskbar, and a window big enough to be a
  // board rather than a dialog. The lanes are laid out for a landscape
  // screen; 1280x800 is the smallest shape they were designed against.
  if (!window.Create(title, origin, size)) {
    return EXIT_FAILURE;
  }
  if (tv) {
    // Borderless, over the whole TV (the non-primary monitor), never asleep.
    tv_surface::FillTargetMonitor(window.GetHandle());
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
