import 'dart:async';
import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../display/widgets/monitor_dropdown.dart';
import '../display/widgets/output_dropdown.dart';
import '../kds/domain/kds_alarm.dart';
import '../kds/state/kds_board.dart';
import '../tv/ports/tv_speech.dart';
import '../tv/state/tv_providers.dart';
import '../tv/state/tv_settings_controller.dart';

/// F2 on the « Écran cuisine »: which screen, which sound output, an alarm
/// test, and quitting. Nothing here touches an order (S6-B, plan §3).
class KitchenTvSettingsDialog extends ConsumerStatefulWidget {
  const KitchenTvSettingsDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const KitchenTvSettingsDialog(),
  );

  /// How long « Tester l'alarme » rings before it stops by itself.
  static const Duration testRingFor = Duration(seconds: 3);

  @override
  ConsumerState<KitchenTvSettingsDialog> createState() =>
      _KitchenTvSettingsDialogState();
}

class _KitchenTvSettingsDialogState
    extends ConsumerState<KitchenTvSettingsDialog> {
  late final Future<(List<TvAudioOutput>, List<TvMonitor>)> _lists;

  @override
  void initState() {
    super.initState();
    final TvSpeech port = ref.read(tvSpeechProvider);
    _lists = Future.wait(<Future<Object>>[port.outputs(), port.monitors()])
        .then(
          (List<Object> r) =>
              (r[0] as List<TvAudioOutput>, r[1] as List<TvMonitor>),
        );
  }

  Future<void> _testAlarm() async {
    final sink = ref.read(kdsAlarmSinkProvider);
    await sink.ring(KdsAlarmRegister.waiting);
    await Future<void>.delayed(KitchenTvSettingsDialog.testRingFor);
    await sink.silence();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TvSettings settings = ref.watch(tvSettingsProvider);
    final TvSettingsController controller = ref.read(
      tvSettingsProvider.notifier,
    );
    return AlertDialog(
      title: Text(l10n.kitchenTvSettingsTitle),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<(List<TvAudioOutput>, List<TvMonitor>)>(
          future: _lists,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<(List<TvAudioOutput>, List<TvMonitor>)> snap,
              ) {
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final (List<TvAudioOutput> outputs, List<TvMonitor> monitors) =
                    snap.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(l10n.displaySettingsMonitor),
                    MonitorDropdown(
                      monitors: monitors,
                      selectedId: settings.monitorId,
                      onChanged: (String? id) {
                        controller.chooseMonitor(id);
                        ref.read(tvSpeechProvider).placeOnMonitor(id);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.tvSettingsOutput),
                    OutputDropdown(
                      outputs: outputs,
                      selectedId: settings.outputId,
                      onChanged: controller.chooseOutput,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.tvSettingsHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () =>
              ServicesBinding.instance.exitApplication(AppExitType.required),
          child: Text(l10n.kitchenTvQuit),
        ),
        OutlinedButton(
          key: const ValueKey<String>('kitchen-tv-test-alarm'),
          onPressed: () => unawaited(_testAlarm()),
          child: Text(l10n.kitchenTvTestAlarm),
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
