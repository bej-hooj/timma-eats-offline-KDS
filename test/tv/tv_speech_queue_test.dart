import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timma_kds/tv/domain/tv_rules.dart';
import 'package:timma_kds/tv/domain/tv_utterance.dart';
import 'package:timma_kds/tv/ports/tv_speech.dart';
import 'package:timma_kds/tv/state/tv_speech_queue.dart';

/// A port that holds every utterance until the test releases it.
class _GatedSpeech implements TvSpeech {
  final List<String> started = <String>[];
  final List<Completer<void>> gates = <Completer<void>>[];
  bool fail = false;

  @override
  Future<List<TvAudioOutput>> outputs() async => const <TvAudioOutput>[];

  @override
  Future<List<TvVoice>> voices() async => const <TvVoice>[];

  @override
  Future<List<TvMonitor>> monitors() async => const <TvMonitor>[];

  @override
  Future<void> placeOnMonitor(String? id) async {}

  @override
  Future<void> playSound(String asset, {String? outputId}) async {}

  @override
  Future<void> stopSound() async {}

  @override
  Future<void> say(TvUtterance u, {String? outputId, String? voiceId}) {
    started.add('${u.text}@$outputId');
    if (fail) {
      throw StateError('boom');
    }
    final Completer<void> c = Completer<void>();
    gates.add(c);
    return c.future;
  }
}

TvUtterance prep(String t) => TvUtterance(text: t, priority: TvUtterancePriority.preparing);
TvUtterance ready(String t) => TvUtterance(text: t, priority: TvUtterancePriority.ready, chime: true);
TvUtterance again(String t) => TvUtterance(text: t, priority: TvUtterancePriority.ready, reread: true);

void main() {
  test('speaks one at a time, in order, to the chosen output', () async {
    final _GatedSpeech port = _GatedSpeech();
    final TvSpeechQueue q = TvSpeechQueue(speech: port, target: () => (outputId: 'lg', voiceId: null));
    q.enqueue(<TvUtterance>[prep('a'), ready('b')]);
    await Future<void>.delayed(Duration.zero);
    expect(port.started, <String>['a@lg']);
    port.gates.first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(port.started, <String>['a@lg', 'b@lg']);
  });

  test('a fresh announcement jumps ahead of waiting re-reads', () async {
    final _GatedSpeech port = _GatedSpeech();
    final TvSpeechQueue q = TvSpeechQueue(speech: port, target: () => (outputId: null, voiceId: null));
    q.enqueue(<TvUtterance>[ready('speaking')]);
    await Future<void>.delayed(Duration.zero);
    q.enqueue(<TvUtterance>[again('r1'), again('r2')]);
    q.enqueue(<TvUtterance>[ready('fresh')]);
    expect(q.pending.map((TvUtterance u) => u.text), <String>['fresh', 'r1', 'r2']);
  });

  test('bounded: re-reads drop first, then preparation; fresh « prête » stays', () async {
    final _GatedSpeech port = _GatedSpeech();
    final TvSpeechQueue q = TvSpeechQueue(speech: port, target: () => (outputId: null, voiceId: null));
    q.enqueue(<TvUtterance>[ready('speaking')]);
    await Future<void>.delayed(Duration.zero);
    q.enqueue(<TvUtterance>[
      again('old'),
      prep('p0'),
      for (int i = 0; i < TvRules.maxQueue - 2; i++) ready('r$i'),
      ready('late'),
      ready('later'),
    ]);
    expect(q.pending, hasLength(TvRules.maxQueue));
    expect(q.pending.map((TvUtterance u) => u.text), isNot(contains('old')));
    expect(q.pending.map((TvUtterance u) => u.text), isNot(contains('p0')));
    expect(q.pending.map((TvUtterance u) => u.text), containsAll(<String>['late', 'later']));
  });

  test('silentFor: null while speaking, measured from when the voice stopped', () async {
    DateTime now = DateTime.utc(2026, 11, 27, 12);
    final _GatedSpeech port = _GatedSpeech();
    final TvSpeechQueue q = TvSpeechQueue(speech: port, target: () => (outputId: null, voiceId: null), clock: () => now);
    q.enqueue(<TvUtterance>[prep('a')]);
    expect(q.silentFor(now), isNull);
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 5));
    port.gates.single.complete();
    await Future<void>.delayed(Duration.zero);
    expect(q.silentFor(now.add(const Duration(seconds: 7))), const Duration(seconds: 7));
  });


  test('a failing port does not stop the queue', () async {
    final _GatedSpeech port = _GatedSpeech()..fail = true;
    final TvSpeechQueue q = TvSpeechQueue(speech: port, target: () => (outputId: null, voiceId: null));
    q.enqueue(<TvUtterance>[prep('a'), prep('b')]);
    await Future<void>.delayed(Duration.zero);
    expect(port.started, <String>['a@null', 'b@null']);
  });
}
