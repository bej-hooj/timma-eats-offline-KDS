import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tv/state/tv_providers.dart';
import '../tv/state/tv_settings_controller.dart';

/// Puts this window back on the screen the manager chose (F2 → « Écran »),
/// once, after the first frame. Nothing chosen = the native default stays
/// (salle: first non-primary monitor, cuisine: last) — see
/// `windows/runner/tv_surface.cpp`.
class DisplayPlacement extends ConsumerStatefulWidget {
  const DisplayPlacement({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DisplayPlacement> createState() => _DisplayPlacementState();
}

class _DisplayPlacementState extends ConsumerState<DisplayPlacement> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final String? id = ref.read(tvSettingsProvider).monitorId;
      if (id != null) {
        ref.read(tvSpeechProvider).placeOnMonitor(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
