import 'package:pos_core/pos_core.dart';

/// The tablet KDS board's lanes, mirroring the web board's `KdsColumn` exactly
/// (`timmaeat-webapp/app/Services/Orders/Admin/KdsColumn.php`).
///
/// Two implementations of one kitchen board is a drift risk, so the semantics
/// are restated here in full rather than reinvented, and the tests below them
/// are ported from `KdsLanesTest`. If these two ever disagree, the same ticket
/// behaves differently depending on which screen a cook is standing at.
abstract final class KdsLane {
  /// Kiosk tickets that have been rung but not paid. **The tablet board's own
  /// lane, which the web board does not have**: a kiosk order is
  /// `pending_payment` until someone takes cash at the counter, and it is the
  /// lane that releases tickets to the kitchen (plan §K5, "counter lane
  /// first").
  static const String counter = 'counter';

  /// Not a status — `placed` that has not reached its fire time yet
  /// (ECOSYSTEM §6.3). Keeping it a lane rather than a status is what stops an
  /// order for 8pm being cooked at noon.
  ///
  /// ⚠ **This lane is currently always empty, and that is a known gap, not a
  /// design.** `PosOrder` carries no fire time: `pos_core` was built for the
  /// kiosk, whose take-away tickets are never scheduled. But `mergeRemoteOrder`
  /// syncs *web* orders down to this board, and a scheduled web order arriving
  /// without its fire time lands in [newTickets] — a cook making an 8pm order
  /// at noon, which is exactly what this lane exists to prevent. Closing it
  /// needs `fire_at` on `PosOrder` and on the store schema; until then the
  /// tablet board must not be pointed at a branch that takes scheduled orders.
  /// Recorded in `docs/kiosk-k5-kds-2026-08-16.md`.
  static const String scheduled = 'scheduled';

  static const String newTickets = PosOrderStatus.placed;
  static const String preparing = PosOrderStatus.preparing;
  static const String ready = PosOrderStatus.ready;
  static const String outForDelivery = PosOrderStatus.outForDelivery;

  static const List<String> all = <String>[
    counter,
    scheduled,
    newTickets,
    preparing,
    ready,
    outForDelivery,
  ];

  /// **The take-away spine.** Every order rung at the borne travels exactly
  /// this path, and it is the same path a McDonald's board shows: pay, land,
  /// cook, collect. These four always render, empty or not — a cook has to be
  /// able to see where a ticket goes *next*, so an empty *Prêtes* at 10:00 is
  /// information, not clutter.
  static const List<String> spine = <String>[
    counter,
    newTickets,
    preparing,
    ready,
  ];

  /// Which lanes to draw, given what is actually on the board.
  ///
  /// ⚠ **A lane that cannot receive anything is noise that costs real work.**
  /// Six fixed columns at [KdsScale.laneWidth] on an 844 dp board means a cook
  /// scrolls past two permanently empty ones to reach the tickets. *Programmées*
  /// can never fill at all today — `PosOrder` carries no fire time — and *En
  /// livraison* is meaningless for a customer who ordered at the counter and is
  /// standing there waiting. Both hold orders that came from the app or the web,
  /// so both appear **only while they hold one**, and disappear when they empty.
  ///
  /// Order is preserved from [all]: the board's left-to-right reading is a
  /// promise, and lanes must not swap places under a cook's hand.
  static List<String> visible(Map<String, List<PosOrder>> lanes) => <String>[
    for (final String lane in all)
      if (spine.contains(lane) || (lanes[lane]?.isNotEmpty ?? false)) lane,
  ];

  /// The transition a one-tap button performs, decided by the card's **STATUS**
  /// — never by the lane it happens to be drawn in.
  ///
  /// ⚠ **This distinction is the whole of the web board's bug B1**
  /// (2026-08-06). The board deliberately draws `accepted` in the Preparing
  /// lane, so a lane-keyed map offered every one of those cards
  /// `preparing → ready`. The state machine has no `accepted → ready`, so the
  /// RPC refused it as `bad_transition` — permanently, because the status never
  /// changed and a refresh could not help. The entire kitchen board was stuck.
  ///
  /// A lane is a presentation choice. A transition is a state-machine fact.
  /// Conflating them is what broke it, so status is the only input here too.
  ///
  /// [mode] decides only the last hop: a delivery order leaves for the road,
  /// everything else is handed straight over.
  static String? advanceFor(String status, String mode) {
    switch (status) {
      case PosOrderStatus.placed:
        return PosOrderStatus.accepted;
      case PosOrderStatus.accepted:
        return PosOrderStatus.preparing;
      case PosOrderStatus.preparing:
        return PosOrderStatus.ready;
      case PosOrderStatus.ready:
        return mode == PosOrderMode.delivery
            ? PosOrderStatus.outForDelivery
            : PosOrderStatus.completed;
      case PosOrderStatus.outForDelivery:
        return PosOrderStatus.completed;
      default:
        // `pending_payment` included: it does not advance, it gets *settled*.
        // Offering a cook an advance button on an unpaid ticket is how food
        // leaves the building without being paid for.
        return null;
    }
  }

  /// Which lane a ticket is drawn in.
  ///
  /// `accepted` deliberately has no lane of its own: accepting is what silences
  /// the alert and moves a ticket into the cook's hands, so it shares
  /// [preparing]. The status still exists in the state machine — see
  /// [advanceFor].
  static String? laneFor(PosOrder order) {
    if (order.isTerminal) {
      return null;
    }
    switch (order.status) {
      case PosOrderStatus.pendingPayment:
        return counter;
      case PosOrderStatus.placed:
        // See [scheduled]: with no fire time on PosOrder there is nothing to
        // compare `now` against, so every placed ticket reads as immediate.
        return newTickets;
      case PosOrderStatus.accepted:
      case PosOrderStatus.preparing:
        return preparing;
      case PosOrderStatus.ready:
        return ready;
      case PosOrderStatus.outForDelivery:
        return outForDelivery;
      default:
        return null;
    }
  }

  /// Every open ticket, bucketed. Lanes that are empty are still present, so a
  /// board never has to reason about a missing key.
  static Map<String, List<PosOrder>> board(
    Iterable<PosOrder> orders, {
    required DateTime now,
  }) {
    final Map<String, List<PosOrder>> lanes = <String, List<PosOrder>>{
      for (final String lane in all) lane: <PosOrder>[],
    };
    for (final PosOrder order in orders) {
      final String? lane = laneFor(order);
      if (lane != null) {
        lanes[lane]!.add(order);
      }
    }
    for (final List<PosOrder> lane in lanes.values) {
      lane.sort(_oldestFirst);
    }
    return lanes;
  }

  /// Oldest first: the ticket that has been waiting longest is the one the
  /// kitchen owes. Ordered by the age clock (see [KdsSla.agedFrom]), so a
  /// scheduled ticket does not jump the queue by having been placed hours ago.
  static int _oldestFirst(PosOrder a, PosOrder b) =>
      KdsSla.agedFrom(a).compareTo(KdsSla.agedFrom(b));
}

/// How a card ages, and when it turns amber then red.
///
/// The thresholds are the web board's, from `config/kds.php`
/// (`KDS_AMBER_MINUTES` 10, `KDS_RED_MINUTES` 20). They are stated here as the
/// same numbers rather than fetched, because the tablet board must work with
/// the WAN down — but they are the *same* numbers on purpose, and the ported
/// tests below are what keeps them so.
abstract final class KdsSla {
  static const Duration amberAfter = Duration(minutes: 10);
  static const Duration redAfter = Duration(minutes: 20);

  /// How often the *waiting* alarm re-sounds while a ticket sits unclaimed.
  /// A nag interval, not a duration: it stops when the lane empties.
  static const Duration reminderEvery = Duration(seconds: 60);

  /// The clock a card ages against.
  ///
  /// ⚠ **A scheduled ticket must age from its fire time, not from when it was
  /// placed.** An order taken at noon for 8pm that ages from `placedAt` arrives
  /// on the board already red — the exact defect the scheduled-order pass found
  /// on the web board (memory `timma-scheduled-alarm-2026-08-15`). A board that
  /// lies about age is worse than a board that was briefly empty.
  ///
  /// This is a single expression on purpose: it is the one place a fire time
  /// has to be honoured, so when `PosOrder` grows `fireAt` (see
  /// [KdsLane.scheduled]) this becomes `order.fireAt ?? order.placedAtDevice`
  /// and every lane, sort and alarm inherits it at once.
  static DateTime agedFrom(PosOrder order) => order.placedAtDevice;

  static KdsUrgency urgencyOf(PosOrder order, DateTime now) {
    final Duration waited = now.difference(agedFrom(order));
    if (waited >= redAfter) {
      return KdsUrgency.red;
    }
    if (waited >= amberAfter) {
      return KdsUrgency.amber;
    }
    return KdsUrgency.calm;
  }
}

enum KdsUrgency { calm, amber, red }
