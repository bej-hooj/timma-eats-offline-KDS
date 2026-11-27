import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../../kds/link/kds_link.dart';
import '../../display/display_chrome.dart';
import '../../display/display_placement.dart';
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

  Future<void> _openSettings() => TvSettingsDialog.show(context);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TvBoardState state = ref.watch(tvBoardProvider);
    final bool connected = ref.watch(
      kdsLinkProvider.select((KdsLinkState s) => s.connected),
    );
    return DisplayPlacement(
      child: DisplayChrome(
        onOpenSettings: () => unawaited(_openSettings()),
        child: Scaffold(
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double headerH = box.maxHeight * _headerShare;
              return Column(
                children: <Widget>[
                  SizedBox(
                    height: headerH,
                    child: TvHeader(
                      now: state.now,
                      connected: connected,
                      onOpenSettings: _openSettings,
                    ),
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
    );
  }
}
