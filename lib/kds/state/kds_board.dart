import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import '../domain/kds_lanes.dart';

/// The board as the kitchen sees it, plus the two actions a cook can take.
///
/// Reads come straight from the local store and **never** from the network:
/// this is the surface built to keep working when the WAN is gone (§23.1). The
/// hub pushes changes in over the LAN or the relay; the board just re-reads.
class KdsBoardState {
  const KdsBoardState({
    required this.lanes,
    required this.now,
    this.lastError,
    this.expiredJustNow = 0,
  });

  final Map<String, List<PosOrder>> lanes;

  /// The clock every card ages against, held in state so a rebuild does not
  /// silently re-age the board mid-frame.
  final DateTime now;

  /// A refusal the cook needs to see — a transition the guard rejected, for
  /// instance. Never a stack trace.
  final String? lastError;

  /// How many unpaid tickets the last sweep expired, for the one summary line
  /// §23 asks for instead of a burst of alerts.
  final int expiredJustNow;

  List<PosOrder> lane(String name) => lanes[name] ?? const <PosOrder>[];

  /// The lane the *waiting* alarm watches. Unclaimed work, not all work.
  bool get hasUnclaimedWork =>
      lane(KdsLane.counter).isNotEmpty || lane(KdsLane.newTickets).isNotEmpty;
}

class KdsBoardController extends Notifier<KdsBoardState> {
  Timer? _tick;
  Timer? _sweep;

  /// Survives a refresh. Held on the controller rather than recomputed per
  /// read, because the board re-reads every 5 s: a count that lived only in the
  /// state object would flash the expiry line up and wipe it before a cook
  /// plating an order ever looked at the screen. It clears when someone
  /// acknowledges it, or when the next sweep replaces it.
  int _expiredJustNow = 0;

  /// The board re-reads on this cadence. It is a **local SQLite read**, not the
  /// web board's 5-second HTTP poll, so it costs nothing and mainly exists to
  /// re-age the cards — a card that only re-colours when someone taps is a
  /// card that lies about how long the kitchen has had it.
  static const Duration refreshEvery = Duration(seconds: 5);

  /// The 15-minute rule is the engine's; this is only how often the board asks
  /// it to run. A minute is far finer than the rule it enforces and costs one
  /// local query.
  static const Duration sweepEvery = Duration(minutes: 1);

  @override
  KdsBoardState build() {
    ref.onDispose(() {
      _tick?.cancel();
      _sweep?.cancel();
    });
    _tick = Timer.periodic(refreshEvery, (_) => refresh());
    _sweep = Timer.periodic(sweepEvery, (_) => expireStaleUnpaid());
    return _read();
  }

  PosEngine get _engine => ref.read(kdsEngineProvider);

  KdsBoardState _read({String? error}) {
    final DateTime now = DateTime.now().toUtc();
    return KdsBoardState(
      lanes: KdsLane.board(_engine.store.openOrders(), now: now),
      now: now,
      lastError: error,
      expiredJustNow: _expiredJustNow,
    );
  }

  void refresh() => state = _read();

  /// **One button, cash, no picker and no typed note.** A kitchen tablet during
  /// a rush is the worst place in the building to ask someone to type into a
  /// text field, and a tender picker on a surface that may be offline would
  /// offer methods it cannot verify (§7.4: the tablet KDS is cash-only,
  /// enforced at the RPC by device role, not by hiding a button).
  void settleCash(String clientId) {
    try {
      _engine.settleCounterCash(clientId);
      state = _read();
    } on PosError catch (error) {
      state = _read(error: error.code);
    }
  }

  /// Advances a ticket by its **status**, never by the lane it is drawn in.
  /// See [KdsLane.advanceFor] — conflating the two is what stuck the web board.
  void advance(PosOrder order) {
    final String? to = KdsLane.advanceFor(order.status, order.mode);
    if (to == null) {
      return;
    }
    try {
      _engine.advance(order.clientId, to);
      state = _read();
    } on PosError catch (error) {
      state = _read(error: error.code);
    }
  }

  /// The local 15-minute sweep. Reported as **one summary count**, not one
  /// alert per ticket: a board that shouts eleven times while a cook is plating
  /// is a board the cook learns to ignore (§22.1).
  void expireStaleUnpaid() {
    final List<PosOrder> expired = _engine.expireStaleUnpaid();
    if (expired.isNotEmpty) {
      _expiredJustNow = expired.length;
    }
    state = _read();
  }

  /// Clears the expiry line. It is dismissed by a **person**, never by a timer:
  /// tickets vanishing from the counter lane is the one board event a cook must
  /// not be able to miss by looking away.
  void acknowledgeExpired() {
    _expiredJustNow = 0;
    state = _read();
  }

  void dismissError() => state = _read();
}

final NotifierProvider<KdsBoardController, KdsBoardState> kdsBoardProvider =
    NotifierProvider<KdsBoardController, KdsBoardState>(
      KdsBoardController.new,
    );

/// Overridden at the shell with the real engine, and in tests with one built on
/// an in-memory store. Nothing in `lib/kds/` constructs an engine itself.
final Provider<PosEngine> kdsEngineProvider = Provider<PosEngine>(
  (Ref ref) => throw UnimplementedError(
    'kdsEngineProvider must be overridden at the app shell',
  ),
);
