import 'package:flutter_test/flutter_test.dart';
import 'package:timma_kds/kds/domain/kds_alarm.dart';
import 'package:timma_kds/kitchen_tv/output_alarm_sink.dart';
import 'package:timma_kds/tv/data/silent_tv_speech.dart';
import 'package:timma_kds/tv/domain/tv_utterance.dart';
import 'package:timma_kds/tv/ports/tv_speech.dart';

class _Throwing extends SilentTvSpeech {
  @override
  Future<void> playSound(String asset, {String? outputId}) => throw StateError('x');
  @override
  Future<void> stopSound() => throw StateError('x');
  @override
  Future<void> say(TvUtterance u, {String? outputId, String? voiceId}) async {}
  @override
  Future<List<TvMonitor>> monitors() async => const <TvMonitor>[];
}

void main() {
  test('rings the register file on the chosen output; silence stops it', () async {
    final SilentTvSpeech port = SilentTvSpeech();
    final OutputAlarmSink sink = OutputAlarmSink(port: port, outputId: () => 'usb-card');
    await sink.ring(KdsAlarmRegister.waiting);
    await sink.silence();
    expect(port.sounds, <String>['kds_waiting.wav@usb-card']);
    expect(port.stops, 1);
  });

  test('a failing port never throws out of the sink', () async {
    final OutputAlarmSink sink = OutputAlarmSink(port: _Throwing(), outputId: () => null);
    await sink.ring(KdsAlarmRegister.notice);
    await sink.silence();
  });

  test('every register maps to a bare .wav file name', () {
    for (final KdsAlarmRegister r in KdsAlarmRegister.values) {
      expect(OutputAlarmSink.fileFor(r), matches(RegExp(r'^[a-z_]+\.wav$')));
    }
  });
}
