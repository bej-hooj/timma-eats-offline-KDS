import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/tv_utterance.dart';
import '../ports/tv_speech.dart';

/// [TvSpeech] over the Windows runner's native channel
/// (`windows/runner/tv_speech_channel.cpp`): WinRT `SpeechSynthesizer` played
/// by a `MediaPlayer` whose `AudioDevice` is the output the manager chose — so
/// the voice reaches the LG TV over HDMI while the kitchen alarm stays on the
/// PC's default output.
///
/// Every failure is logged (never the text) and swallowed: the screen goes on.
class WindowsTvSpeech implements TvSpeech {
  WindowsTvSpeech({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName);

  /// Keep identical to `kTvSpeechChannel` in `tv_speech_channel.h`.
  static const String channelName = 'timma/tv_speech';
  static const String _listOutputs = 'listOutputs';
  static const String _listVoices = 'listVoices';
  static const String _say = 'say';

  final MethodChannel _channel;

  @override
  Future<List<TvAudioOutput>> outputs() async {
    final List<Map<Object?, Object?>> rows = await _list(_listOutputs);
    return <TvAudioOutput>[
      for (final Map<Object?, Object?> r in rows)
        if (r['id'] is String && r['name'] is String)
          TvAudioOutput(id: r['id']! as String, name: r['name']! as String, isDefault: r['isDefault'] == true),
    ];
  }

  @override
  Future<List<TvVoice>> voices() async {
    final List<Map<Object?, Object?>> rows = await _list(_listVoices);
    return <TvVoice>[
      for (final Map<Object?, Object?> r in rows)
        if (r['id'] is String && r['name'] is String)
          TvVoice(
            id: r['id']! as String,
            name: r['name']! as String,
            language: r['language'] is String ? r['language']! as String : '',
          ),
    ];
  }

  @override
  Future<void> say(TvUtterance utterance, {String? outputId, String? voiceId}) async {
    try {
      await _channel.invokeMethod<void>(_say, <String, Object?>{
        'text': utterance.text,
        'chime': utterance.chime,
        'outputId': outputId,
        'voiceId': voiceId,
      });
    } on PlatformException catch (e) {
      debugPrint('[TvSpeech] say failed: ${e.code}');
    } on MissingPluginException {
      debugPrint('[TvSpeech] native channel missing');
    }
  }

  Future<List<Map<Object?, Object?>>> _list(String method) async {
    try {
      final List<Object?>? raw = await _channel.invokeMethod<List<Object?>>(method);
      return <Map<Object?, Object?>>[
        for (final Object? row in raw ?? const <Object?>[])
          if (row is Map<Object?, Object?>) row,
      ];
    } on PlatformException catch (e) {
      debugPrint('[TvSpeech] $method failed: ${e.code}');
      return const <Map<Object?, Object?>>[];
    } on MissingPluginException {
      debugPrint('[TvSpeech] native channel missing');
      return const <Map<Object?, Object?>>[];
    }
  }
}
