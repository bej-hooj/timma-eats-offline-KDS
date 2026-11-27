import 'package:pos_core/pos_core.dart';

import '../../kds/domain/kds_lanes.dart';

import 'tv_rules.dart';
import 'tv_ticket.dart';

/// The TV's two columns, projected from the local store. Pure: same inputs,
/// same board — no clock read, no I/O.
class TvBoard {
  const TvBoard({
    this.preparing = const <TvTicket>[],
    this.ready = const <TvTicket>[],
  });

  static const TvBoard empty = TvBoard();

  /// Oldest first — the next ones to come out of the kitchen.
  final List<TvTicket> preparing;

  /// Newest first — the one a customer is looking for is on top.
  final List<TvTicket> ready;

  /// Builds the board from the store's open orders.
  ///
  /// * [orders] — `PosStore.openOrders()` (terminal orders are already gone).
  /// * [linesOf] — `PosStore.linesOf`, read only for tickets that are shown.
  /// * [now] — UTC; a ready ticket older than [TvRules.readyVisibleFor] is
  ///   dropped.
  ///
  /// A ticket is in « En préparation » / « Prêt » exactly when the KDS shows
  /// it in its « En préparation » / « Prêtes » lane. Kiosk orders only; a ticket with no printable number is skipped (a
  /// customer cannot match a blank tile to a slip).
  static TvBoard project({
    required List<PosOrder> orders,
    required List<PosOrderLine> Function(String clientId) linesOf,
    required DateTime now,
  }) {
    final List<PosOrder> preparing = <PosOrder>[];
    final List<PosOrder> ready = <PosOrder>[];
    for (final PosOrder order in orders) {
      if (order.source != TvRules.source || _labelOf(order).isEmpty) {
        continue;
      }
      // The kitchen board's own lane rule — one definition, so the TV can
      // never disagree with what the cooks see.
      final String? lane = KdsLane.laneFor(order);
      if (lane == KdsLane.preparing) {
        preparing.add(order);
      } else if (lane == KdsLane.ready &&
          now.difference(order.statusChangedAt) < TvRules.readyVisibleFor) {
        ready.add(order);
      }
    }
    preparing.sort(
      (PosOrder a, PosOrder b) => a.placedAtDevice.compareTo(b.placedAtDevice),
    );
    ready.sort(
      (PosOrder a, PosOrder b) => b.statusChangedAt.compareTo(a.statusChangedAt),
    );
    return TvBoard(
      preparing: <TvTicket>[
        for (final PosOrder o in preparing.take(TvRules.maxPerColumn))
          _ticket(o, TvColumn.preparing, const <PosOrderLine>[]),
      ],
      ready: <TvTicket>[
        for (final PosOrder o in ready.take(TvRules.maxPerColumn))
          _ticket(o, TvColumn.ready, linesOf(o.clientId)),
      ],
    );
  }

  /// True while [ticket] became ready less than [TvRules.highlightFor] ago.
  static bool isHighlighted(TvTicket ticket, DateTime now) =>
      ticket.column == TvColumn.ready &&
      now.difference(ticket.since) < TvRules.highlightFor;

  static String _labelOf(PosOrder order) =>
      order.ticketLabelOrNull ?? order.dailyCode ?? order.orderCode ?? '';

  static TvTicket _ticket(
    PosOrder order,
    TvColumn column,
    List<PosOrderLine> lines,
  ) => TvTicket(
    clientId: order.clientId,
    label: _labelOf(order),
    column: column,
    since: order.statusChangedAt,
    lines: <TvSpokenLine>[
      for (final PosOrderLine line in lines)
        TvSpokenLine(
          quantity: line.quantity,
          name: line.variantNameFr == null || line.variantNameFr!.isEmpty
              ? line.nameFr
              : '${line.nameFr} ${line.variantNameFr}',
        ),
    ],
  );
}
