import '../domain/tv_utterance.dart';
import '../ports/tv_speech.dart';

/// [TvSpeech] for platforms without the native channel, and for tests:
/// records what it was asked to say, plays nothing.
class SilentTvSpeech implements TvSpeech {
  SilentTvSpeech({
    this.availableOutputs = const <TvAudioOutput>[],
    this.availableVoices = const <TvVoice>[],
  });

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
}
