import '../domain/tv_utterance.dart';
import '../ports/tv_speech.dart';

/// [TvSpeech] for platforms without the native channel, and for tests:
/// records what it was asked to say, plays nothing.
class SilentTvSpeech implements TvSpeech {
  SilentTvSpeech({
    this.availableOutputs = const <TvAudioOutput>[],
    this.availableVoices = const <TvVoice>[],
    this.availableMonitors = const <TvMonitor>[],
  });

  final List<TvMonitor> availableMonitors;

  /// Monitor placements asked for, in order.
  final List<String?> placements = <String?>[];

  /// Sounds played, as `asset@output`.
  final List<String> sounds = <String>[];

  int stops = 0;

  final List<TvAudioOutput> availableOutputs;
  final List<TvVoice> availableVoices;

  /// Every utterance, in the order it was spoken.
  final List<TvUtterance> said = <TvUtterance>[];

  /// The output each utterance was sent to (parallel to [said]).
  final List<String?> outputsUsed = <String?>[];

  @override
  Future<List<TvAudioOutput>> outputs() async => availableOutputs;

  @override
  Future<List<TvVoice>> voices() async => availableVoices;

  @override
  Future<void> say(TvUtterance utterance, {String? outputId, String? voiceId}) async {
    said.add(utterance);
    outputsUsed.add(outputId);
  }

  @override
  Future<List<TvMonitor>> monitors() async => availableMonitors;

  @override
  Future<void> placeOnMonitor(String? id) async => placements.add(id);

  @override
  Future<void> playSound(String asset, {String? outputId}) async =>
      sounds.add('$asset@$outputId');

  @override
  Future<void> stopSound() async => stops++;
}
