#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "tv_speech_channel.h"
#include "tv_surface.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // |surface| = which screen this process is. A display surface (Écran
  // salle, Écran cuisine) registers the native window/sound channel and
  // keeps itself full-screen on its TV monitor.
  explicit FlutterWindow(
      const flutter::DartProject& project,
      tv_surface::Surface surface = tv_surface::Surface::kKitchen);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Which screen this process drives.
  tv_surface::Surface surface_;

  // The display surfaces' native channel; null in the kitchen process.
  std::unique_ptr<TvSpeechChannel> tv_speech_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
