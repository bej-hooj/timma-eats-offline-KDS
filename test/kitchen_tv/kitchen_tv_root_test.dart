import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/design/time_util.dart';
import 'package:timma_kds/kds/access/kds_view.dart';
import 'package:timma_kds/kds/access/kds_view_controller.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/domain/kds_alarm.dart';
import 'package:timma_kds/kds/pairing/pairing_screen.dart';
import 'package:timma_kds/kds/presentation/board_screen.dart';
import 'package:timma_kds/kds/state/kds_board.dart';
import 'package:timma_kds/kitchen_tv/kitchen_tv_root.dart';
import 'package:timma_kds/tv/data/silent_tv_speech.dart';
import 'package:timma_kds/tv/ports/tv_speech.dart';
import 'package:timma_kds/tv/state/tv_providers.dart';
import 'package:timma_kds/tv/state/tv_settings_controller.dart';

import '../tv/tv_fixtures.dart';

void main() {
  const PosDeviceIdentity identity = PosDeviceIdentity(
    deviceId: 'ecran-cuisine',
    branchId: 'branch-1',
    role: PosDeviceRole.kds,
    label: 'Écran cuisine',
  );
  late PosStore store;
  late RecordingAlarmSink alarm;
  late SilentTvSpeech port;

  setUpAll(TimeUtil.init);
  setUp(() {
    store = SqlitePosStore.inMemory();
    store.writeMeta(KdsViewController.metaKey, KdsView.kitchen);
    alarm = RecordingAlarmSink();
    port = SilentTvSpeech(
      availableMonitors: const <TvMonitor>[
        TvMonitor(id: r'\\.\DISPLAY1', name: 'Portable', isPrimary: true, width: 1366, height: 768),
        TvMonitor(id: r'\\.\DISPLAY3', name: 'LG (VGA)', width: 1920, height: 1080),
      ],
      availableOutputs: const <TvAudioOutput>[TvAudioOutput(id: 'usb', name: 'Carte son USB')],
    );
  });
  tearDown(() => store.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsStoreProvider.overrideWithValue(store),
          kdsAlarmSinkProvider.overrideWithValue(alarm),
          kdsReadOnlyProvider.overrideWithValue(true),
          tvSpeechProvider.overrideWithValue(port),
        ],
        child: const KitchenTvRoot(),
      ),
    );
    await tester.pump();
  }

  testWidgets('unpaired → the pairing screen', (WidgetTester tester) async {
    await pump(tester);
    expect(find.byType(KdsPairingScreen), findsOneWidget);
  });

  testWidgets('paired → the kitchen board, no « À encaisser », at 1280×720', (WidgetTester tester) async {
    store.writeIdentity(identity);
    final DateTime now = DateTime.now().toUtc();
    store.insertOrder(order('p', number: 2, placed: now, changed: now), <PosOrderLine>[line('Koki', 1)]);
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(KdsBoardScreen), findsOneWidget);
    expect(find.text('En préparation'), findsWidgets);
    expect(find.text('À encaisser'), findsNothing);
  });

  testWidgets('F2 → settings: choose the VGA TV and the USB card; test alarm rings the sink', (WidgetTester tester) async {
    store.writeIdentity(identity);
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text("Réglages de l'écran cuisine"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('display-monitor')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('LG (VGA)').last);
    await tester.pumpAndSettle();
    expect(store.readMeta(TvSettingsController.monitorKey), r'\\.\DISPLAY3');
    expect(port.placements, contains(r'\\.\DISPLAY3'));

    await tester.tap(find.byKey(const ValueKey<String>('tv-output')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carte son USB').last);
    await tester.pumpAndSettle();
    expect(store.readMeta(TvSettingsController.outputKey), 'usb');

    await tester.tap(find.byKey(const ValueKey<String>('kitchen-tv-test-alarm')));
    await tester.pump(const Duration(seconds: 4));
    expect(alarm.rung, contains(KdsAlarmRegister.waiting));
    expect(alarm.silenced, greaterThan(0));
  });

  testWidgets('a stored screen choice is applied at start', (WidgetTester tester) async {
    store.writeIdentity(identity);
    store.writeMeta(TvSettingsController.monitorKey, r'\\.\DISPLAY3');
    await pump(tester);
    await tester.pump();
    expect(port.placements, <String?>[r'\\.\DISPLAY3']);
  });
}
