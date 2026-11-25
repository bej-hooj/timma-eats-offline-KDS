import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import '../audio/kds_alarm_sink.dart';
import '../domain/kds_alarm.dart';
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
    this.lines = const <String, List<PosOrderLine>>{},
    this.lastError,
    this.alarmMuted = false,
  });

  final Map<String, List<PosOrder>> lanes;

  /// What was actually ordered, per `clientId`.
  ///
  /// ⚠ **The board used to show a ticket number and a total and nothing else.**
  /// A cook cannot cook a total. The lines have been on the wire the whole time
  /// — `BoardOrder` carries them and the merge writes them to the local store —
  /// and the card simply threw them away. Read here, once per refresh, so the
  /// card stays a pure function of its inputs.
  final Map<String, List<PosOrderLine>> lines;

  List<PosOrderLine> linesOf(String clientId) =>
      lines[clientId] ?? const <PosOrderLine>[];

  /// The clock every card ages against, held in state so a rebuild does not
  /// silently re-age the board mid-frame.
  final DateTime now;

  /// A refusal the cook needs to see — a transition the guard rejected, for
  /// instance. Never a stack trace.
  final String? lastError;

  List<PosOrder> lane(String name) => lanes[name] ?? const <PosOrder>[];

  /// The lane the *waiting* alarm watches. Unclaimed work, not all work.
  bool get hasUnclaimedWork =>
      lane(KdsLane.counter).isNotEmpty || lane(KdsLane.newTickets).isNotEmpty;

  /// True while the alarm is nagging and nobody has muted it — the one
  /// condition that puts *Couper l'alarme* on the screen. Derived rather than
  /// stored, so the button cannot outlive the noise.
  bool get alarming => hasUnclaimedWork && !alarmMuted;

  /// Whether the current run has been silenced. Not a setting: it clears itself
  /// when the lane empties, and a new arrival overrides it.
  final bool alarmMuted;
}

class KdsBoardController extends Notifier<KdsBoardState> {
  Timer? _tick;

  /// The rule half of the alarm. Held on the controller, not rebuilt per read:
  /// its whole job is remembering which tickets have already been heard, and a
  /// [KdsAlarm] reconstructed every five seconds would have an empty seen-set
  /// every five seconds — an alarm that screams continuously, which a kitchen
  /// silences by turning the tablet's volume down, which is how a board ends up
  /// mute for the rest of the shift.
  final KdsAlarm _alarm = KdsAlarm();

  /// The board re-reads on this cadence. It is a **local SQLite read**, not the
  /// web board's 5-second HTTP poll, so it costs nothing and mainly exists to
  /// re-age the cards — a card that only re-colours when someone taps is a
  /// card that lies about how long the kitchen has had it.
  static const Duration refreshEvery = Duration(seconds: 5);

  @override
  KdsBoardState build() {
    ref.onDispose(() {
      _tick?.cancel();
    });
    _tick = Timer.periodic(refreshEvery, (_) => refresh());
    // ⚠ No automatic expiry sweep (owner, 2026-11-25): unpaid À encaisser
    // tickets vanished after 15 min "with no reason". A ticket now stays until
    // a person settles or deletes it (S10).
    return _read();
  }

  KdsAlarmSink get _sink => ref.read(kdsAlarmSinkProvider);

  /// Push what the cook just did, now rather than on the next tick.
  void _publish() => ref.read(kdsIntentPublisherProvider)();

  PosEngine get _engine => ref.read(kdsEngineProvider);

  KdsBoardState _read({String? error}) {
    final DateTime now = DateTime.now().toUtc();
    final Map<String, List<PosOrder>> lanes = KdsLane.board(
      _engine.store.openOrders(),
      now: now,
    );

    // ⚠ **Every read evaluates the alarm.** Not only the ones a cook triggered:
    // an order arriving from the kiosk changes the board without anyone
    // touching it, and that is precisely the arrival the kitchen must hear. The
    // decision is [KdsAlarm]'s; this only carries it to a speaker.
    final KdsAlarmCue? cue = _alarm.evaluate(lanes: lanes, now: now);
    if (cue != null) {
      unawaited(_sink.ring(cue.register));
    }

    return KdsBoardState(
      lanes: lanes,
      now: now,
      lines: <String, List<PosOrderLine>>{
        for (final List<PosOrder> lane in lanes.values)
          for (final PosOrder order in lane)
            order.clientId: _engine.store.linesOf(order.clientId),
      },
      lastError: error,
      alarmMuted: _alarm.muted,
    );
  }

  void refresh() => state = _read();

  /// *Couper l'alarme.* Silences the sound that is playing **and** the rest of
  /// this nag — but not the next order: [KdsAlarm.mute] is cleared the moment
  /// something new arrives, so muting a run can never swallow an arrival.
  void muteAlarm() {
    _alarm.mute();
    unawaited(_sink.silence());
    state = _read();
  }

  /// **One button, cash, no picker and no typed note.** A kitchen tablet during
  /// a rush is the worst place in the building to ask someone to type into a
  /// text field, and a tender picker on a surface that may be offline would
  /// offer methods it cannot verify (§7.4: the tablet KDS is cash-only,
  /// enforced at the RPC by device role, not by hiding a button).
  void settleCash(String clientId) {
    try {
      _engine.settleCounterCash(clientId);
      state = _read();
      _publish();
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
      // ⚠ **The tap is only half of it.** `PosEngine.advance` moves the local
      // row and queues an envelope addressed to the hub; if nothing drains that
      // queue the cook sees *Prêt* and the kiosk never does. Waiting for the
      // three-second pump would be correct but visibly slow at a counter.
      _publish();
    } on PosError catch (error) {
      state = _read(error: error.code);
    }
  }

  /// The cashier removes an unpaid ticket — no payment, the customer left
  /// (owner, 2026-11-25, S10). The confirmation is the screen's job; this is
  /// the act. Goes to the hub, then the cloud, as a cancel with a reason.
  void cancelUnpaid(String clientId) {
    try {
      _engine.cancelUnpaid(clientId);
      state = _read();
      _publish();
    } on PosError catch (error) {
      state = _read(error: error.code);
    }
  }

  void dismissError() => state = _read();
}

final NotifierProvider<KdsBoardController, KdsBoardState> kdsBoardProvider =
    NotifierProvider<KdsBoardController, KdsBoardState>(KdsBoardController.new);

/// How the board pushes a cook's action to the kiosk, without knowing what a
/// hub is.
///
/// The direction of this dependency is deliberate and mirrors the kiosk's
/// `kioskBoardPublisherProvider`: the board must keep working with the socket
/// down — that is the entire premise (§23.1) — so the transport is told about
/// the board, never the other way round. Defaults to a no-op, which is exactly
/// right for an unpaired tablet and for a widget test.
final Provider<void Function()> kdsIntentPublisherProvider =
    Provider<void Function()>((Ref ref) => () {});

/// The alarm's speaker.
///
/// Defaults to the **real** one rather than to silence. A default of silence is
/// how a board ships mute: everything compiles, every test passes, and the only
/// thing that tells you is a kitchen that misses an order — so the production
/// path is the one you get for free and a test has to ask for quiet.
///
/// [AudioAlarmSink] builds its player lazily and swallows platform failures, so
/// this default costs a widget test nothing.
final Provider<KdsAlarmSink> kdsAlarmSinkProvider = Provider<KdsAlarmSink>((
  Ref ref,
) {
  final KdsAlarmSink sink = AudioAlarmSink();
  ref.onDispose(sink.dispose);
  return sink;
});

/// Overridden at the shell with the real engine, and in tests with one built on
/// an in-memory store. Nothing in `lib/kds/` constructs an engine itself.
/// The open local database, available **before** the board has an identity.
///
/// Pairing needs it: a tablet out of the box has no engine, because an engine
/// needs a branch and a branch is what pairing grants. The store exists from
/// the first launch, so the pairing screen can write the identity it earns.
final Provider<PosStore> kdsStoreProvider = Provider<PosStore>(
  (Ref ref) => throw UnimplementedError(
    'kdsStoreProvider must be overridden at the app shell',
  ),
);

/// **Does this board still belong to a kiosk?**
///
/// ⚠ An identity in the local database is NOT the same thing as being paired,
/// and treating it as such is what stranded a real tablet. An iOS reinstall
/// keeps the app's Documents directory, so `kds.db` — and the identity in it —
/// survives; the keychain survives too. Meanwhile the kiosk had been
/// reinstalled and had never heard of that device. The board therefore looked
/// paired, went straight to the lanes, and sat there for ever: the kiosk sent
/// it nothing, and **the board offered no way back to the pairing screen**.
/// There was no route out of that state from the product at all.
///
/// So the hub's own answer decides. When it refuses this board's credential —
/// `unauthenticated`, `bad_signature` — the board is not paired, whatever its
/// database says, and it goes back to asking for six digits.
abstract final class KdsPairingGate {
  static const String _key = 'pairing.required';

  /// The kiosk refused us, or a manager asked to move this board. Either way
  /// the identity on disk is no longer a claim to anything.
  static void require(PosStore store) => store.writeMeta(_key, '1');

  static void satisfied(PosStore store) => store.writeMeta(_key, '');

  static bool isRequired(PosStore store) => store.readMeta(_key) == '1';
}

/// This board's identity, or null until it has been paired.
///
/// Held in a provider rather than read once at startup so the app can move from
/// the pairing screen to the board without the manager restarting anything.
class KdsIdentityController extends Notifier<PosDeviceIdentity?> {
  @override
  PosDeviceIdentity? build() {
    final PosStore store = ref.read(kdsStoreProvider);
    // A board the kiosk has refused presents as unpaired, so the shell shows
    // pairing instead of a set of lanes nothing will ever fill.
    return KdsPairingGate.isRequired(store) ? null : store.readIdentity();
  }

  /// Called once, by pairing, after the credential and branch secret are safely
  /// stored. Reads back from the store rather than trusting what it was handed.
  void adopt() {
    final PosStore store = ref.read(kdsStoreProvider);
    KdsPairingGate.satisfied(store);
    state = store.readIdentity();
  }

  /// Send this board back to the pairing screen.
  ///
  /// Called by the link when the kiosk refuses the credential, and by a manager
  /// moving the board to a different kiosk. The identity row is left where it
  /// is — a successful pairing overwrites it — so nothing is destroyed by a
  /// misfire; only the claim to be in service is dropped.
  void requirePairing() {
    KdsPairingGate.require(ref.read(kdsStoreProvider));
    state = null;
  }
}

final NotifierProvider<KdsIdentityController, PosDeviceIdentity?>
kdsIdentityProvider =
    NotifierProvider<KdsIdentityController, PosDeviceIdentity?>(
      KdsIdentityController.new,
    );

/// The board's engine, derived from the identity pairing wrote.
///
/// Derived rather than injected at the root: the board is built the moment
/// pairing succeeds, and a provider that reads the identity is what lets the
/// app move from the pairing screen into service without a restart. Tests and
/// the shell may still override it with a value.
final Provider<PosEngine> kdsEngineProvider = Provider<PosEngine>((Ref ref) {
  final PosDeviceIdentity? identity = ref.watch(kdsIdentityProvider);
  if (identity == null) {
    // Unreachable from the UI: `KdsRoot` shows pairing while this is null, so
    // no screen that reads the engine is ever mounted without one.
    throw StateError('the board is not paired');
  }
  return PosEngine(store: ref.read(kdsStoreProvider), identity: identity);
});
