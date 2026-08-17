import 'package:pos_core/pos_core.dart';

import 'kds_lanes.dart';

/// The two alarm registers, inherited from ECOSYSTEM §22.1 rather than
/// invented. That vocabulary is canon as of v1.15; a third register would mean
/// the kitchen has to learn a sound the rest of the product does not make.
enum KdsAlarmRegister {
  /// **Waiting** — repeats until the lane empties. Unclaimed work is still
  /// unclaimed after 60 seconds, so the alarm keeps asking. Kitchen siren
  /// 880/1320 Hz.
  waiting,

  /// **Notice** — sounds once, never repeats. A scheduled ticket reaching its
  /// fire time is information, not a summons; nagging about it would train the
  /// kitchen to ignore the register that *is* a summons.
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

/// Decides when the board should sound, and in which register.
///
/// Pure logic over the board and a clock — no audio, no platform, no timers —
/// so the rule that actually matters is testable. The scheduled-order pass
/// found the web board's alarm watching only the *Nouvelles* lane, so an order
/// landing in *Programmées* arrived in silence (memory
/// `timma-scheduled-alarm-2026-08-15`); that same pass found a **shared seen-key
/// would have silenced the fire-time alarm entirely**, which is why the two
/// registers keep separate seen-sets here.
class KdsAlarm {
  KdsAlarm({this.reminderEvery = KdsSla.reminderEvery});

  final Duration reminderEvery;

  /// Separate per register, deliberately. A ticket that already sounded its
  /// *notice* must still be able to raise a *waiting* nag, and vice versa — one
  /// shared set is exactly the bug that silenced the fire-time alarm.
  final Set<String> _seenWaiting = <String>{};
  final Set<String> _seenNotice = <String>{};
  DateTime? _lastWaitingAt;
  bool _muted = false;

  bool get muted => _muted;

  /// Muting is per-nag, not permanent: it silences the current run and is
  /// cleared the moment the lane empties, so nobody can mute the kitchen for
  /// the night by accident.
  void mute() => _muted = true;

  /// Call on every board refresh. Returns a cue when the kitchen should hear
  /// something, or null.
  KdsAlarmCue? evaluate({
    required Map<String, List<PosOrder>> lanes,
    required DateTime now,
  }) {
    final List<PosOrder> unclaimed = <PosOrder>[
      ...lanes[KdsLane.counter] ?? const <PosOrder>[],
      ...lanes[KdsLane.newTickets] ?? const <PosOrder>[],
    ];

    if (unclaimed.isEmpty) {
      // The lane emptied: the nag stops on its own and the mute resets. This is
      // why `reminderEvery` is a nag interval and not a duration.
      _lastWaitingAt = null;
      _muted = false;
      _seenWaiting.clear();
      return _noticeFor(lanes, now);
    }

    final Set<String> ids = <String>{
      for (final PosOrder o in unclaimed) o.clientId,
    };
    final bool somethingNew = ids.difference(_seenWaiting).isNotEmpty;
    final DateTime? last = _lastWaitingAt;
    final bool nagDue = last == null || now.difference(last) >= reminderEvery;

    // A newly arrived ticket sounds immediately even mid-mute: muting the
    // current nag must not swallow the *next* order.
    if (somethingNew) {
      _muted = false;
    }
    _seenWaiting
      ..clear()
      ..addAll(ids);

    if (_muted || !(somethingNew || nagDue)) {
      return _noticeFor(lanes, now);
    }
    _lastWaitingAt = now;
    return KdsAlarmCue(register: KdsAlarmRegister.waiting, ticketIds: ids);
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
