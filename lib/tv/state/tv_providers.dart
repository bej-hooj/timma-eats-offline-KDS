import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timma_kds/l10n/app_localizations.dart';

import '../data/silent_tv_speech.dart';
import '../data/windows_tv_speech.dart';
import '../domain/tv_phrases.dart';
import '../ports/tv_speech.dart';
import 'tv_settings_controller.dart';
import 'tv_speech_queue.dart';

/// The speech port: native on Windows, silent elsewhere. Tests override it.
final Provider<TvSpeech> tvSpeechProvider = Provider<TvSpeech>(
  (Ref ref) => Platform.isWindows ? WindowsTvSpeech() : SilentTvSpeech(),
);

/// The TV speaks the restaurant's language, like the KDS (locale fixed `fr`).
const Locale tvLocale = Locale('fr');

/// The sentences, from the arb files — no spoken text is written in Dart.
final Provider<TvPhrases> tvPhrasesProvider = Provider<TvPhrases>((Ref ref) {
  final AppLocalizations l10n = lookupAppLocalizations(tvLocale);
  return TvPhrases(
    preparing: l10n.tvSayPreparing,
    ready: l10n.tvSayReady,
    line: l10n.tvSayLine,
    repeat: l10n.tvSayRepeat,
  );
});

/// One queue for the whole TV, aimed at the output in the settings.
final Provider<TvSpeechQueue> tvSpeechQueueProvider = Provider<TvSpeechQueue>((Ref ref) {
  final TvSpeechQueue queue = TvSpeechQueue(
    speech: ref.watch(tvSpeechProvider),
    target: () {
      final TvSettings s = ref.read(tvSettingsProvider);
      return (outputId: s.outputId, voiceId: s.voiceId);
    },
  );
  ref.onDispose(queue.dispose);
  return queue;
});
