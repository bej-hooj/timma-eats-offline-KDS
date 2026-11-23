import 'package:pos_core/pos_core.dart';

import 'kds_lanes.dart';

/// The three alarm registers, inherited from ECOSYSTEM §22.1 rather than
/// invented. That vocabulary is canon as of v1.25; a fourth register would
/// mean the kitchen has to learn a sound the rest of the product does not make.
enum KdsAlarmRegister {
  /// **Counter** — a ticket waiting to be *paid*. Repeats until the lane
  /// empties. Three rising blips, deliberately nothing like the siren: owner,
  /// 2026-11-23, *"the alarm on the À encaisser step should be different sound
  /// from the Nouvelles step"*. Until that was separated the kitchen had to
  /// walk to the board to learn which of two different jobs it was being
  /// called for — fetch a cook, or fetch the person who takes cash.
  counter,

  /// **Waiting** — a ticket somebody must *cook*. Repeats until the lane
  /// empties: unclaimed work is still unclaimed after 60 seconds, so the alarm
  /// keeps asking. Kitchen siren 880/1320 Hz.
  waiting,

  /// **Notice** — sounds once, never repeats. A scheduled ticket reaching its
  /// fire time is information, not a summons; nagging about it would train the
  /// kitchen to ignore the registers that *are* a summons.
  notice,
}

class KdsAlarmCue {
  const KdsAlarmCue({required this.register, required this.ticketIds});

  final KdsAlarmRegister register;

  /// Which tickets caused it, so a catch-up drain can be reported as one line
  /// rather than one alert per ticket.
  final Set<String> ticketIds;

  int get count => ticketIds.length;
}

/// One repeating register over one lane: its own seen-set, its own nag clock,
/// its own mute.
///
/// ⚠ **Deciding and committing are separate calls.** A board has one speaker,
/// so when both repeating registers come due only one can sound — and the one
/// that loses must NOT be marked heard, or it would be silently swallowed. It
/// keeps its unrecorded arrival and sounds on the next refresh, five seconds
/// later. A register that a busier lane can starve is a register the kitchen
/// learns to distrust.
class _Nag {
  _Nag({required this.register, required this.lane});

  final KdsAlarmRegister register;
  final String lane;

  final Set<String> _seen = <String>{};

  /// What the last evaluation found in this lane, sounded or not.
  ///
  /// ⚠ [mute] needs it. A register that came due but lost the tie has not
  /// recorded its arrival, so without this a mute pressed in that moment would
  /// be overridden immediately by the "a new arrival always rings" rule — the
  /// kitchen silences the counter and the cook alarm starts a second later for
  /// a ticket that was already on the screen they were looking at.
  Set<String> _present = <String>{};

  DateTime? _lastAt;
  bool _muted = false;
  bool _hasWork = false;

  bool get muted => _muted;
  bool get hasWork => _hasWork;

  /// Silences this register's current run. Everything already on the board
  /// counts as heard; only something that arrives *after* this can override it.
  void mute() {
    _muted = true;
    _seen
      ..clear()
      ..addAll(_present);
  }

  /// What this register would sound right now, or null for silence. Updates the
  /// bookkeeping that is *state* rather than sound — an emptied lane, a mute
  /// cleared by an arrival — and leaves the seen-set alone until [commit].
  Set<String>? due(
    Map<String, List<PosOrder>> lanes,
    DateTime now,
    Duration every,
  ) {
    final Set<String> ids = <String>{
      for (final PosOrder o in lanes[lane] ?? const <PosOrder>[]) o.clientId,
    };
    _hasWork = ids.isNotEmpty;
    _present = ids;

    if (ids.isEmpty) {
      // The lane emptied: the nag stops on its own and the mute resets. This is
      // why `reminderEvery` is a nag interval and not a duration.
      _lastAt = null;
      _muted = false;
      _seen.clear();
      return null;
    }

    final bool somethingNew = ids.difference(_seen).isNotEmpty;
    // A newly arrived ticket sounds immediately even mid-mute: muting the
    // current nag must not swallow the *next* order.
    if (somethingNew) {
      _muted = false;
    }
    final DateTime? last = _lastAt;
    final bool nagDue = last == null || now.difference(last) >= every;

    if (_muted || !(somethingNew || nagDue)) {
      // Not sounding, so the arrival is recorded here rather than in `commit`:
      // a muted ticket has been *seen*, and leaving it unseen would make it
      // "new" again on every refresh and defeat the mute.
      _seen
        ..clear()
        ..addAll(ids);
      return null;
    }
    return ids;
  }

  Set<String> commit(Set<String> ids, DateTime now) {
    _seen
      ..clear()
      ..addAll(ids);
    _lastAt = now;
    return ids;
  }
}

/// Decides when the board should sound, and in which register.
///
/// Pure logic over the board and a clock — no audio, no platform, no timers —
/// so the rule that actually matters is testable. The scheduled-order pass
/// found the web board's alarm watching only the *Nouvelles* lane, so an order
/// landing in *Programmées* arrived in silence (memory
/// `timma-scheduled-alarm-2026-08-15`); that same pass found a **shared seen-key
/// would have silenced the fire-time alarm entirely**, which is why every
/// register keeps its own seen-set here.
class KdsAlarm {
  KdsAlarm({this.reminderEvery = KdsSla.reminderEvery});

  final Duration reminderEvery;

  /// ⚠ **Order is precedence.** The counter is first because a customer is
  /// physically standing at it holding cash, while a *Nouvelles* ticket is
  /// paper that will still be there in five seconds (ECOSYSTEM §22.1, v1.25).
  final List<_Nag> _nags = <_Nag>[
    _Nag(register: KdsAlarmRegister.counter, lane: KdsLane.counter),
    _Nag(register: KdsAlarmRegister.waiting, lane: KdsLane.newTickets),
  ];

  /// Separate per register, deliberately — see [_Nag].
  final Set<String> _seenNotice = <String>{};

  bool _mutedWithWork = false;

  /// Whether the run that is currently ringing has been silenced. Not a
  /// setting: it clears itself when the lanes empty, and a new arrival
  /// overrides it. False when there is nothing to ring about, so the screen
  /// cannot show "alarme coupée" over an empty board.
  bool get muted => _mutedWithWork;

  /// Muting is per-nag, not permanent, and covers **all** registers: it is one
  /// button on a tablet and the kitchen reads it as "stop that noise". It is
  /// cleared the moment a lane empties, so nobody can mute the kitchen for the
  /// night by accident.
  void mute() {
    for (final _Nag nag in _nags) {
      nag.mute();
    }
  }

  /// Call on every board refresh. Returns a cue when the kitchen should hear
  /// something, or null.
  KdsAlarmCue? evaluate({
    required Map<String, List<PosOrder>> lanes,
    required DateTime now,
  }) {
    // ⚠ Every nag is evaluated, not just until one fires: `due` is also what
    // notices an emptied lane and clears that register's mute.
    _Nag? winner;
    Set<String>? winningIds;
    for (final _Nag nag in _nags) {
      final Set<String>? ids = nag.due(lanes, now, reminderEvery);
      if (ids != null && winner == null) {
        winner = nag;
        winningIds = ids;
      }
    }

    final Iterable<_Nag> withWork = _nags.where((_Nag n) => n.hasWork);
    _mutedWithWork = withWork.isNotEmpty && withWork.every((_Nag n) => n.muted);

    if (winner == null) {
      return _noticeFor(lanes, now);
    }
    return KdsAlarmCue(
      register: winner.register,
      ticketIds: winner.commit(winningIds!, now),
    );
  }

  /// Scheduled tickets that have just reached the board. Sounds **once** each.
  ///
  /// ⚠ Always empty today: `PosOrder` carries no fire time, so nothing can
  /// enter [KdsLane.scheduled] (see `docs/kiosk-k5-kds-2026-08-16.md`). The
  /// register is wired anyway so that when `fire_at` lands the alarm does not
  /// have to be rediscovered — which is precisely how the web board shipped a
  /// lane whose arrivals nobody could hear.
  KdsAlarmCue? _noticeFor(Map<String, List<PosOrder>> lanes, DateTime now) {
    final List<PosOrder> scheduled =
        lanes[KdsLane.scheduled] ?? const <PosOrder>[];
    final Set<String> fresh = <String>{
      for (final PosOrder o in scheduled)
        if (!_seenNotice.contains(o.clientId)) o.clientId,
    };
    if (fresh.isEmpty) {
      return null;
    }
    _seenNotice.addAll(fresh);
    return KdsAlarmCue(register: KdsAlarmRegister.notice, ticketIds: fresh);
  }
}
