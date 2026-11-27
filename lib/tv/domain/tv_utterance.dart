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
  });

  final String text;
  final TvUtterancePriority priority;
  final bool chime;

  @override
  bool operator ==(Object other) =>
      other is TvUtterance &&
      other.text == text &&
      other.priority == priority &&
      other.chime == chime;

  @override
  int get hashCode => Object.hash(text, priority, chime);

  @override
  String toString() => 'TvUtterance(${priority.name}, chime: $chime)';
}
