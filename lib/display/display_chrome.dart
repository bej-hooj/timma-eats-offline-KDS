import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tv/domain/tv_rules.dart';

/// What every display surface (Écran salle, Écran cuisine) wraps its screen
/// in: **F2** opens the settings, and the mouse cursor hides after
/// [TvRules.cursorHideAfter] without movement — a parked arrow in the middle
/// of a TV is the first thing anyone notices. Movement brings it back.
class DisplayChrome extends StatefulWidget {
  const DisplayChrome({
    required this.child,
    required this.onOpenSettings,
    super.key,
  });

  final Widget child;
  final VoidCallback onOpenSettings;

  @override
  State<DisplayChrome> createState() => _DisplayChromeState();
}

class _DisplayChromeState extends State<DisplayChrome> {
  Timer? _cursorTimer;
  bool _cursorVisible = true;

  @override
  void initState() {
    super.initState();
    _armCursorTimer();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    super.dispose();
  }

  void _armCursorTimer() {
    _cursorTimer?.cancel();
    _cursorTimer = Timer(TvRules.cursorHideAfter, () {
      if (mounted) {
        setState(() => _cursorVisible = false);
      }
    });
  }

  void _onHover() {
    if (!_cursorVisible) {
      setState(() => _cursorVisible = true);
    }
    _armCursorTimer();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.f2): widget.onOpenSettings,
    },
    child: Focus(
      autofocus: true,
      child: MouseRegion(
        cursor: _cursorVisible ? MouseCursor.defer : SystemMouseCursors.none,
        onHover: (_) => _onHover(),
        child: widget.child,
      ),
    ),
  );
}
