import '../domain/tv_utterance.dart';

/// A sound output the TV can speak through (« LG TV (Intel Display Audio) »).
class TvAudioOutput {
  const TvAudioOutput({required this.id, required this.name, this.isDefault = false});

  final String id;
  final String name;

  /// Windows' current default output — where the kitchen alarm plays.
  final bool isDefault;
}

/// An installed synthesizer voice.
class TvVoice {
  const TvVoice({required this.id, required this.name, required this.language});

  final String id;
  final String name;

  /// BCP-47, e.g. `fr-FR`.
  final String language;

  bool get isFrench => language.toLowerCase().startsWith('fr');
}

/// The port the TV speaks through. Implemented natively on Windows
/// (`timma/tv_speech`), silently everywhere else.
///
/// Implementations must never throw into the caller for a speech failure: a
/// TV that cannot speak must keep showing numbers.
abstract interface class TvSpeech {
  /// Sound outputs, or an empty list when the platform cannot list them.
  Future<List<TvAudioOutput>> outputs();

  /// Installed voices, or an empty list.
  Future<List<TvVoice>> voices();

  /// Speaks [utterance] (chime first when asked) and completes when it has
  /// finished playing. A null or unknown [outputId] / [voiceId] uses the
  /// system default.
  Future<void> say(TvUtterance utterance, {String? outputId, String? voiceId});
}
