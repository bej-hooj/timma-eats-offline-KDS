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

/// A screen Windows knows (laptop panel, HDMI TV, VGA TV).
class TvMonitor {
  const TvMonitor({
    required this.id,
    required this.name,
    this.isPrimary = false,
    this.width = 0,
    this.height = 0,
  });

  /// Windows' device name (`\\.\DISPLAY2`) — stable while the cable stays.
  final String id;
  final String name;
  final bool isPrimary;
  final int width;
  final int height;
}

/// The port the TV speaks through. Implemented natively on Windows
/// (`timma/tv_speech`), silently everywhere else.
///
/// Also the display surfaces' window and sound port (S6-B): which monitor the
/// window covers, and alarm sounds played on a chosen output.
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

  /// Screens Windows currently drives; empty when unknown.
  Future<List<TvMonitor>> monitors();

  /// Moves this window full-screen onto monitor [id]; null = the surface's
  /// default (salle: first non-primary, cuisine: last non-primary).
  Future<void> placeOnMonitor(String? id);

  /// Plays `assets/audio/[asset]` (a bare `*.wav` name) on [outputId].
  Future<void> playSound(String asset, {String? outputId});

  /// Stops the sound [playSound] started, now.
  Future<void> stopSound();
}
