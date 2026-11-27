import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/design/time_util.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/state/kds_board.dart';
import 'package:timma_kds/tv/data/silent_tv_speech.dart';
import 'package:timma_kds/tv/domain/tv_rules.dart';
import 'package:timma_kds/tv/domain/tv_utterance.dart';
import 'package:timma_kds/tv/ports/tv_speech.dart';
import 'package:timma_kds/tv/presentation/tv_app.dart';
import 'package:timma_kds/tv/state/tv_board_controller.dart';
import 'package:timma_kds/tv/state/tv_providers.dart';
import 'package:timma_kds/tv/state/tv_settings_controller.dart';

import 'tv_fixtures.dart';

void main() {
  const PosDeviceIdentity identity = PosDeviceIdentity(
    deviceId: 'tv-salle',
    branchId: 'branch-1',
    role: PosDeviceRole.kds,
    label: 'Écran salle',
  );

  late PosStore store;
  late SilentTvSpeech speech;
  late DateTime now;

  setUpAll(TimeUtil.init);

  setUp(() {
    store = SqlitePosStore.inMemory()..writeIdentity(identity);
    speech = SilentTvSpeech(
      availableOutputs: const <TvAudioOutput>[
        TvAudioOutput(id: 'pc', name: 'Haut-parleurs', isDefault: true),
        TvAudioOutput(id: 'lg', name: 'LG TV (Intel Display Audio)'),
      ],
      availableVoices: const <TvVoice>[TvVoice(id: 'v-fr', name: 'Hortense', language: 'fr-FR')],
    );
    now = t0;
  });
  tearDown(() => store.close());

  Future<ProviderContainer> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A ProviderScope (not an external container) so the periodic refresh is
    // cancelled when the test tears the tree down.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsStoreProvider.overrideWithValue(store),
          tvSpeechProvider.overrideWithValue(speech),
          tvClockProvider.overrideWithValue(() => now),
          kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
        ],
        child: const TvApp(),
      ),
    );
    await tester.pump();
    final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(TvApp)));
    return container;
  }

  void put(PosOrder o, List<PosOrderLine> lines) => store.insertOrder(o, lines);

  for (final Size size in const <Size>[Size(1920, 1080), Size(1280, 720)]) {
    testWidgets('renders both columns without overflow at $size', (WidgetTester tester) async {
      for (int i = 0; i < TvRules.maxPerColumn; i++) {
        put(order('p$i', number: i + 1, placed: t0.add(Duration(seconds: i))), <PosOrderLine>[line('Ndolé', 1)]);
        put(order('r$i', number: 50 + i, status: PosOrderStatus.ready, changed: t0), <PosOrderLine>[line('Koki', 1)]);
      }
      await pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('En préparation'), findsOneWidget);
      expect(find.text('Prêt — à récupérer'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      await tester.pump(TvRules.refreshEvery);
    });
  }

  testWidgets('only codes are drawn — no dish names on screen', (WidgetTester tester) async {
    put(order('r', number: 7, status: PosOrderStatus.ready), <PosOrderLine>[line('Ndolé', 2)]);
    await pump(tester, const Size(1920, 1080));
    expect(find.text('07'), findsOneWidget);
    expect(find.textContaining('Ndolé'), findsNothing);
  });

  testWidgets('a ticket made ready is spoken with its dishes, to the chosen output', (WidgetTester tester) async {
    final ProviderContainer c = await pump(tester, const Size(1920, 1080));
    c.read(tvSettingsProvider.notifier).chooseOutput('lg');
    now = t0.add(const Duration(seconds: 5));
    put(order('r', number: 7, status: PosOrderStatus.ready, changed: now), <PosOrderLine>[line('Ndolé', 2)]);
    await tester.pump(TvRules.refreshEvery);
    await tester.pump();
    expect(speech.said.map((TvUtterance u) => u.text), <String>['Commande 0, 7, est prête. 2 Ndolé.']);
    expect(speech.outputsUsed, <String?>['lg']);
    expect(find.text('07'), findsOneWidget);
    // Three minutes later it is gone.
    now = now.add(TvRules.readyVisibleFor);
    await tester.pump(TvRules.refreshEvery);
    expect(find.text('07'), findsNothing);
  });

  testWidgets('F2 opens the settings with the outputs; the choice is kept', (WidgetTester tester) async {
    final ProviderContainer c = await pump(tester, const Size(1920, 1080));
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text('Réglages de l\'écran salle'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('tv-output')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LG TV (Intel Display Audio)').last);
    await tester.pumpAndSettle();
    expect(c.read(tvSettingsProvider).outputId, 'lg');
    expect(store.readMeta(TvSettingsController.outputKey), 'lg');
    await tester.tap(find.byKey(const ValueKey<String>('tv-test-voice')));
    await tester.pump();
    expect(speech.said.single.priority, TvUtterancePriority.ready);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Réglages de l\'écran salle'), findsNothing);
  });

  testWidgets('the TV never rings the kitchen alarm', (WidgetTester tester) async {
    // A new, unclaimed ticket is exactly what makes the kitchen board ring.
    put(order('n', number: 3), const <PosOrderLine>[]);
    final ProviderContainer c = await pump(tester, const Size(1920, 1080));
    final RecordingAlarmSink alarm = c.read(kdsAlarmSinkProvider) as RecordingAlarmSink;
    await tester.pump(TvRules.refreshEvery * 3);
    expect(alarm.rung, isEmpty);
    expect(find.text('03'), findsOneWidget);
  });
}
