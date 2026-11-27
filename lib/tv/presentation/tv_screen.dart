import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../../kds/link/kds_link.dart';
import '../domain/tv_rules.dart';
import '../state/tv_board_controller.dart';
import 'tv_settings_dialog.dart';
import 'widgets/tv_column.dart';
import 'widgets/tv_header.dart';

/// The dining-room screen: header, « En préparation », « Prêt ». Layout only —
/// the columns come from [tvBoardProvider], the voice from its queue.
class TvScreen extends ConsumerStatefulWidget {
  const TvScreen({super.key});

  @override
  ConsumerState<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends ConsumerState<TvScreen> {
  static const double _headerShare = 0.11;
  static const double _readyShare = 0.55;

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

  /// A mouse arrow parked in the middle of a TV is the first thing a customer
  /// notices. It hides after [TvRules.cursorHideAfter] and returns on movement.
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

  Future<void> _openSettings() => TvSettingsDialog.show(context);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TvBoardState state = ref.watch(tvBoardProvider);
    final bool connected = ref.watch(kdsLinkProvider.select((KdsLinkState s) => s.connected));
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f2): () => unawaited(_openSettings()),
      },
      child: Focus(
        autofocus: true,
        child: MouseRegion(
          cursor: _cursorVisible ? MouseCursor.defer : SystemMouseCursors.none,
          onHover: (_) => _onHover(),
          child: Scaffold(
            body: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double headerH = box.maxHeight * _headerShare;
                return Column(
                  children: <Widget>[
                    SizedBox(
                      height: headerH,
                      child: TvHeader(now: state.now, connected: connected, onOpenSettings: _openSettings),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            flex: ((1 - _readyShare) * 100).round(),
                            child: TvColumnView(
                              key: const ValueKey<String>('tv-column-preparing'),
                              title: l10n.tvColumnPreparing,
                              emptyText: l10n.tvEmptyPreparing,
                              tickets: state.board.preparing,
                              ready: false,
                              now: state.now,
                            ),
                          ),
                          Expanded(
                            flex: (_readyShare * 100).round(),
                            child: TvColumnView(
                              key: const ValueKey<String>('tv-column-ready'),
                              title: l10n.tvColumnReady,
                              emptyText: l10n.tvEmptyReady,
                              tickets: state.board.ready,
                              ready: true,
                              now: state.now,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
