/// Which column of the TV a ticket sits in.
enum TvColumn { preparing, ready }

/// One spoken line of a ready ticket: « 2 Ndolé ».
class TvSpokenLine {
  const TvSpokenLine({required this.quantity, required this.name});

  final int quantity;

  /// French name, with the variant appended when the line has one.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is TvSpokenLine && other.quantity == quantity && other.name == name;

  @override
  int get hashCode => Object.hash(quantity, name);
}

/// One tile on the TV and what may be said about it. Immutable.
///
/// Only [label] is ever drawn; [lines] are only spoken (plan §3 — no dishes,
/// prices or names on a screen the whole dining room can read).
class TvTicket {
  const TvTicket({
    required this.clientId,
    required this.label,
    required this.column,
    required this.since,
    this.lines = const <TvSpokenLine>[],
  });

  final String clientId;

  /// The number on the customer's slip, e.g. `AD45`.
  final String label;

  final TvColumn column;

  /// When the order entered its current status (UTC) — ages the ready tiles.
  final DateTime since;

  final List<TvSpokenLine> lines;

  /// Identity of "this ticket in this column", used so a re-read never
  /// announces the same move twice.
  String get announceKey => '$clientId|${column.name}';
}
