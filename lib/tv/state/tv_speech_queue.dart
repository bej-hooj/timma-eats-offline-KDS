import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../domain/tv_rules.dart';
import '../domain/tv_utterance.dart';
import '../ports/tv_speech.dart';

/// Speaks utterances one at a time, in order — two moves never talk over each
/// other — and keeps the backlog bounded.
///
/// When the backlog is full, the oldest « en préparation » is dropped to make
/// room; a « prête » is never dropped for a preparation one. If it is all
/// « prête », the oldest of those goes (rotation will say it again).
class TvSpeechQueue {
  TvSpeechQueue({required this.speech, required this.target});

  /// The port every utterance goes through.
  final TvSpeech speech;

  /// Where to speak, read at the moment each utterance starts so a change in
  /// the settings applies to the next one.
  final ({String? outputId, String? voiceId}) Function() target;

  final Queue<TvUtterance> _pending = Queue<TvUtterance>();
  bool _running = false;
  bool _disposed = false;

  /// What is waiting (not the one being spoken). For tests and diagnostics.
  List<TvUtterance> get pending => List<TvUtterance>.unmodifiable(_pending);

  void enqueue(List<TvUtterance> utterances) {
    if (_disposed) {
      return;
    }
    for (final TvUtterance u in utterances) {
      if (_pending.length >= TvRules.maxQueue) {
        _dropOne();
      }
      _pending.addLast(u);
    }
    unawaited(_run());
  }

  void _dropOne() {
    final TvUtterance? prep = _pending
        .where((TvUtterance u) => u.priority == TvUtterancePriority.preparing)
        .firstOrNull;
    if (prep != null) {
      _pending.remove(prep);
    } else {
      _pending.removeFirst();
    }
  }

  Future<void> _run() async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      while (_pending.isNotEmpty && !_disposed) {
        final TvUtterance next = _pending.removeFirst();
        final ({String? outputId, String? voiceId}) where = target();
        try {
          await speech.say(next, outputId: where.outputId, voiceId: where.voiceId);
        } on Object catch (e) {
          // The port promises not to throw; if one does, the queue lives on.
          debugPrint('[TvSpeechQueue] utterance failed: ${e.runtimeType}');
        }
      }
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
  }
}
