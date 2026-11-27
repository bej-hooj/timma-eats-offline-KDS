import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import '../../kds/state/kds_board.dart';
import '../domain/tv_announcer.dart';
import '../domain/tv_board.dart';
import '../domain/tv_rules.dart';
import 'tv_providers.dart';

/// What the TV screen draws.
class TvBoardState {
  const TvBoardState({required this.board, required this.now});

  final TvBoard board;

  /// The clock the tiles age against (highlight), held in state so a rebuild
  /// does not re-age the board mid-frame.
  final DateTime now;
}

/// Re-reads the TV's local store every [TvRules.refreshEvery], projects the
/// two columns and hands any new announcement to the speech queue.
///
/// Reads only — the TV never calls an engine transition (plan §8).
class TvBoardController extends Notifier<TvBoardState> {
  Timer? _tick;
  TvAnnouncer? _announcer;

  @override
  TvBoardState build() {
    ref.onDispose(() => _tick?.cancel());
    _tick = Timer.periodic(TvRules.refreshEvery, (_) => refresh());
    _announcer = TvAnnouncer(phrases: ref.read(tvPhrasesProvider));
    return _read();
  }

  /// Re-read now. Called by the timer; safe to call any time.
  void refresh() => state = _read();

  TvBoardState _read() {
    final DateTime now = ref.read(tvClockProvider)();
    final PosStore store = ref.read(kdsEngineProvider).store;
    final TvBoard board = TvBoard.project(
      orders: store.openOrders(),
      linesOf: store.linesOf,
      now: now,
    );
    ref.read(tvSpeechQueueProvider).enqueue(_announcer!.next(board, now));
    return TvBoardState(board: board, now: now);
  }
}

/// The TV's clock, UTC. Tests override it to walk time forward.
final Provider<DateTime Function()> tvClockProvider = Provider<DateTime Function()>(
  (Ref ref) => () => DateTime.now().toUtc(),
);

final NotifierProvider<TvBoardController, TvBoardState> tvBoardProvider =
    NotifierProvider<TvBoardController, TvBoardState>(TvBoardController.new);
