import '../domain/kds_lanes.dart';

/// Which board this KDS shows (owner, 2026-11-25): **no login, no password**.
/// The tablet opens on a picker and remembers the choice. ECOSYSTEM §25.2.
///
/// An operational choice on a trusted, paired device — not a security gate.
/// The trust boundary stays the pairing approval on the borne.
abstract final class KdsView {
  /// « Cuisine » — the cooking pipeline, *Nouvelles → Prêtes* (+ *Programmées*
  /// / *En livraison* while they hold tickets).
  static const String kitchen = 'kitchen';

  /// « Caisse paiement » — *À encaisser* only.
  static const String cashier = 'cashier';

  static const List<String> all = <String>[kitchen, cashier];

  /// Lanes [view] may draw, in [KdsLane.all] order. Null (no choice yet — a
  /// widget test, or a board mid-switch) means every lane.
  static List<String> lanesFor(String? view) => switch (view) {
    kitchen => <String>[
      KdsLane.scheduled,
      KdsLane.newTickets,
      KdsLane.preparing,
      KdsLane.ready,
      KdsLane.outForDelivery,
    ],
    cashier => const <String>[KdsLane.counter],
    _ => KdsLane.all,
  };

  /// [visible] restricted to [view], order kept.
  static List<String> restrict(List<String> visible, String? view) {
    final List<String> allowed = lanesFor(view);
    return <String>[
      for (final String lane in visible)
        if (allowed.contains(lane)) lane,
    ];
  }

  /// A stored value this build does not know (an older or newer app) reads as
  /// "not chosen", so the picker shows instead of an empty board.
  static String? parse(String? raw) => all.contains(raw) ? raw : null;
}
