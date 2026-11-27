import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../domain/tv_rules.dart';
import '../domain/tv_utterance.dart';
import '../ports/tv_speech.dart';

/// Speaks utterances one at a time, in order — two moves never talk over each
/// other — and keeps the backlog bounded.
///
/// * A fresh announcement goes **ahead of** every waiting re-read, so a number
///   that just became ready is never stuck behind a full board re-read.
/// * When the backlog is full, re-reads drop first, then the oldest « en
///   préparation »; a fresh « prête » is the last thing ever dropped.
/// * [silentFor] tells the announcer how long the voice has been quiet, which
///   is what starts the next re-read cycle.
class TvSpeechQueue {
  TvSpeechQueue({required this.speech, required this.target, DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc()) {
    _idleSince = _clock();
  }

  /// The port every utterance goes through.
  final TvSpeech speech;

  /// Where to speak, read at the moment each utterance starts so a change in
  /// the settings applies to the next one.
  final ({String? outputId, String? voiceId}) Function() target;

  final DateTime Function() _clock;
  final Queue<TvUtterance> _pending = Queue<TvUtterance>();
  bool _running = false;

  /// When the queue last fell silent; null while something is waiting or
  /// being spoken.
  DateTime? _idleSince;

  /// How long nothing has been said, or null while speaking.
  Duration? silentFor(DateTime now) {
    final DateTime? since = _idleSince;
    return since == null ? null : now.difference(since);
  }
  bool _disposed = false;

  /// What is waiting (not the one being spoken). For tests and diagnostics.
  List<TvUtterance> get pending => List<TvUtterance>.unmodifiable(_pending);

  void enqueue(List<TvUtterance> utterances) {
    if (_disposed) {
      return;
    }
    if (utterances.isEmpty) {
      return;
    }
    for (final TvUtterance u in utterances) {
      if (_pending.length >= TvRules.maxQueue) {
        _dropOne();
      }
      if (u.reread) {
        _pending.addLast(u);
      } else {
        _insertBeforeRereads(u);
      }
    }
    _idleSince = null;
    unawaited(_run());
  }

  void _insertBeforeRereads(TvUtterance u) {
    final List<TvUtterance> all = _pending.toList();
    final int at = all.indexWhere((TvUtterance p) => p.reread);
    if (at < 0) {
      _pending.addLast(u);
      return;
    }
    all.insert(at, u);
    _pending
      ..clear()
      ..addAll(all);
  }

  void _dropOne() {
    final TvUtterance victim =
        _pending.where((TvUtterance u) => u.reread).lastOrNull ??
        _pending
            .where((TvUtterance u) => u.priority == TvUtterancePriority.preparing)
            .firstOrNull ??
        _pending.first;
    _pending.remove(victim);
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
      if (_pending.isEmpty) {
        _idleSince = _clock();
      }
    }
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
  }
}
