import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../domain/kds_alarm.dart';

/// The alarm's voice, behind a seam.
///
/// [KdsAlarm] decides *whether* to sound; this decides *how*. They are separate
/// because the decision is the part with the rules in it — two registers, two
/// seen-sets, a nag that stops when the lane empties — and a rule that can only
/// be exercised by listening to a tablet is a rule nobody checks again.
abstract interface class KdsAlarmSink {
  Future<void> ring(KdsAlarmRegister register);

  /// Cuts the sound now. Muting is a decision [KdsAlarm] owns; this only makes
  /// the current beep stop mid-file, so *Couper l'alarme* is instant rather
  /// than "instant after the two seconds already playing".
  Future<void> silence();

  Future<void> dispose();
}

/// Used by tests and by any host build with no audio device. It records what it
/// was asked to play, so the wiring can be proven without a speaker.
class RecordingAlarmSink implements KdsAlarmSink {
  final List<KdsAlarmRegister> rung = <KdsAlarmRegister>[];
  int silenced = 0;

  @override
  Future<void> ring(KdsAlarmRegister register) async => rung.add(register);

  @override
  Future<void> silence() async => silenced++;

  @override
  Future<void> dispose() async {}
}

/// Plays the two tones through the platform's audio session.
///
/// **One player, reused.** A player per beep leaks a native decoder per ticket
/// on a tablet that runs for a fourteen-hour service; the same player is
/// re-pointed at whichever asset the register calls for.
class AudioAlarmSink implements KdsAlarmSink {
  AudioAlarmSink({AudioPlayer Function()? open}) : _open = open ?? _default;

  static AudioPlayer _default() => AudioPlayer(playerId: 'kds-alarm');

  static const String _waitingAsset = 'audio/kds_waiting.wav';
  static const String _noticeAsset = 'audio/kds_notice.wav';

  /// ⚠ **Built on first ring, never in the constructor.** `AudioPlayer()` talks
  /// to the platform the moment it exists, so constructing one eagerly would
  /// make the provider unusable in every widget test — and a sink that only
  /// works when a test remembers to override it is a sink the production
  /// default eventually gets wrong.
  final AudioPlayer Function() _open;
  AudioPlayer? _player;
  bool _configured = false;

  /// ⚠ **`playback`, not `ambient`.** A kitchen tablet lives face-up on a shelf
  /// with its ring switch in whatever position the last person left it, and
  /// under any other iOS category the silent switch mutes the alarm outright —
  /// which is a board that shows new tickets in silence, the exact failure this
  /// whole feature exists to end.
  ///
  /// On Android the usage is `alarm` for the same reason: it plays on the alarm
  /// stream, so a tablet whose media volume somebody turned down for a radio
  /// still rings.
  Future<AudioPlayer> _configure() async {
    final AudioPlayer player = _player ??= _open();
    if (_configured) {
      return player;
    }
    // ⚠ **This await comes first on purpose.** `AudioPlayer`'s constructor
    // starts talking to the platform straight away and reports the outcome on
    // its own future; the first player call is what observes it. On a host with
    // no audio plugin — every widget test — configuring the global session
    // first would throw before anything looked at that future, and an
    // unobserved async error fails the whole test file rather than just the
    // alarm.
    await player.setVolume(1);
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const <AVAudioSessionOptions>{
            AVAudioSessionOptions.duckOthers,
          },
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          // The board is the only thing on this tablet. Holding the screen on
          // while it rings means the cue is heard *and* seen.
          stayAwake: true,
        ),
      ),
    );
    await player.setReleaseMode(ReleaseMode.stop);
    _configured = true;
    return player;
  }

  @override
  Future<void> ring(KdsAlarmRegister register) async {
    try {
      final AudioPlayer player = await _configure();
      await player.stop();
      await player.play(
        AssetSource(
          register == KdsAlarmRegister.waiting ? _waitingAsset : _noticeAsset,
        ),
      );
    } on Object catch (error) {
      // A silent alarm is bad; a board that crashes because a speaker is busy
      // is worse. The kitchen still has the screen.
      debugPrint('[KdsAlarm] could not sound $register: $error');
    }
  }

  @override
  Future<void> silence() async {
    try {
      await _player?.stop();
    } on Object {
      debugPrint('[KdsAlarm] could not stop the sound');
    }
  }

  @override
  Future<void> dispose() async => _player?.dispose();
}
