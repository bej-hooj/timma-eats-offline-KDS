/// How much a queued utterance matters when the queue is full.
enum TvUtterancePriority {
  /// « … en préparation » — dropped first.
  preparing,

  /// « … est prête » — never dropped for a preparation one.
  ready,
}

/// One thing to say, optionally preceded by the chime.
class TvUtterance {
  const TvUtterance({
    required this.text,
    required this.priority,
    this.chime = false,
    this.reread = false,
  });

  final String text;
  final TvUtterancePriority priority;
  final bool chime;

  /// Part of the board re-read cycle, not a fresh move. A fresh announcement
  /// always goes ahead of re-reads in the queue, and re-reads drop first.
  final bool reread;

  @override
  bool operator ==(Object other) =>
      other is TvUtterance &&
      other.text == text &&
      other.priority == priority &&
      other.chime == chime &&
      other.reread == reread;

  @override
  int get hashCode => Object.hash(text, priority, chime, reread);

  @override
  String toString() =>
      'TvUtterance(${priority.name}, chime: $chime, reread: $reread)';
}
