import 'package:flutter/foundation.dart';

import '../kds/audio/kds_alarm_sink.dart';
import '../kds/domain/kds_alarm.dart';
import '../tv/ports/tv_speech.dart';

/// The kitchen alarm on a CHOSEN sound output (S6-B): the « Écran cuisine »
/// rings on the back TV (USB sound card → PC Audio In), while the laptop's
/// default output keeps the cashier's sounds. Same registers, same files as
/// [AudioAlarmSink]; only where the sound goes differs.
class OutputAlarmSink implements KdsAlarmSink {
  OutputAlarmSink({required this.port, required this.outputId});

  /// The native window/sound port.
  final TvSpeech port;

  /// The output chosen in the settings, read at each ring.
  final String? Function() outputId;

  /// `audio/kds_waiting.wav` → `kds_waiting.wav`: the native side accepts a
  /// bare file name only (path-traversal guard).
  static String fileFor(KdsAlarmRegister register) =>
      AudioAlarmSink.assetFor(register).split('/').last;

  @override
  Future<void> ring(KdsAlarmRegister register) async {
    try {
      await port.playSound(fileFor(register), outputId: outputId());
    } on Object catch (error) {
      debugPrint('[KdsAlarm] could not sound $register: ${error.runtimeType}');
    }
  }

  @override
  Future<void> silence() async {
    try {
      await port.stopSound();
    } on Object {
      debugPrint('[KdsAlarm] could not stop the sound');
    }
  }

  @override
  Future<void> dispose() async {}
}
