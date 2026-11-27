import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../domain/tv_speech_text.dart';
import '../domain/tv_utterance.dart';
import '../ports/tv_speech.dart';
import '../state/tv_providers.dart';
import '../state/tv_settings_controller.dart';

/// F2 / double-tap on the clock: where the voice goes, which voice, a test,
/// and quitting the TV. Nothing else — no action here touches an order.
class TvSettingsDialog extends ConsumerStatefulWidget {
  const TvSettingsDialog({super.key});

  /// Opens the dialog over [context].
  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const TvSettingsDialog());

  /// The sample code spoken by « Tester la voix ».
  static const String sampleCode = 'AD45';

  @override
  ConsumerState<TvSettingsDialog> createState() => _TvSettingsDialogState();
}

class _TvSettingsDialogState extends ConsumerState<TvSettingsDialog> {
  late final Future<(List<TvAudioOutput>, List<TvVoice>)> _lists;

  @override
  void initState() {
    super.initState();
    final TvSpeech speech = ref.read(tvSpeechProvider);
    _lists = Future.wait(<Future<Object>>[speech.outputs(), speech.voices()]).then(
      (List<Object> r) => (r[0] as List<TvAudioOutput>, r[1] as List<TvVoice>),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TvSettings settings = ref.watch(tvSettingsProvider);
    final TvSettingsController controller = ref.read(tvSettingsProvider.notifier);
    return AlertDialog(
      title: Text(l10n.tvSettingsTitle),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<(List<TvAudioOutput>, List<TvVoice>)>(
          future: _lists,
          builder: (BuildContext context, AsyncSnapshot<(List<TvAudioOutput>, List<TvVoice>)> snap) {
            if (!snap.hasData) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            final (List<TvAudioOutput> outputs, List<TvVoice> allVoices) = snap.data!;
            final List<TvVoice> voices = <TvVoice>[
              ...allVoices.where((TvVoice v) => v.isFrench),
              ...allVoices.where((TvVoice v) => !v.isFrench),
            ];
            final bool knownOutput = outputs.any((TvAudioOutput o) => o.id == settings.outputId);
            final bool knownVoice = voices.any((TvVoice v) => v.id == settings.voiceId);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.tvSettingsOutput),
                DropdownButton<String?>(
                  key: const ValueKey<String>('tv-output'),
                  isExpanded: true,
                  value: knownOutput ? settings.outputId : null,
                  items: <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(child: Text(l10n.tvSettingsDefaultOutput)),
                    for (final TvAudioOutput o in outputs)
                      DropdownMenuItem<String?>(value: o.id, child: Text(o.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: controller.chooseOutput,
                ),
                const SizedBox(height: 16),
                Text(l10n.tvSettingsVoice),
                DropdownButton<String?>(
                  key: const ValueKey<String>('tv-voice'),
                  isExpanded: true,
                  value: knownVoice ? settings.voiceId : null,
                  items: <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(child: Text(l10n.tvSettingsDefaultVoice)),
                    for (final TvVoice v in voices)
                      DropdownMenuItem<String?>(
                        value: v.id,
                        child: Text('${v.name} (${v.language})', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: controller.chooseVoice,
                ),
                if (voices.isNotEmpty && !voices.any((TvVoice v) => v.isFrench)) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(l10n.tvSettingsNoFrenchVoice, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                Text(l10n.tvSettingsHint, style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => ServicesBinding.instance.exitApplication(AppExitType.required),
          child: Text(l10n.tvSettingsQuit),
        ),
        OutlinedButton(
          key: const ValueKey<String>('tv-test-voice'),
          onPressed: () => ref.read(tvSpeechQueueProvider).enqueue(<TvUtterance>[
            TvUtterance(
              text: l10n.tvSettingsTestPhrase(TvSpeechText.spell(TvSettingsDialog.sampleCode)),
              priority: TvUtterancePriority.ready,
              chime: true,
            ),
          ]),
          child: Text(l10n.tvSettingsTest),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          child: Text(l10n.tvSettingsClose),
        ),
      ],
    );
  }
}
