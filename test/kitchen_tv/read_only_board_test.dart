import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/kds/access/kds_view.dart';
import 'package:timma_kds/kds/access/kds_view_controller.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/kds_app.dart';
import 'package:timma_kds/kds/presentation/widgets/kds_ticket_card.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

import '../tv/tv_fixtures.dart';

/// S6-B — the « Écran cuisine » is the kitchen board with every action off.
void main() {
  const PosDeviceIdentity identity = PosDeviceIdentity(
    deviceId: 'ecran-cuisine',
    branchId: 'branch-1',
    role: PosDeviceRole.kds,
    label: 'Écran cuisine',
  );
  late PosStore store;
  late RecordingAlarmSink alarm;

  setUp(() {
    store = SqlitePosStore.inMemory()..writeIdentity(identity);
    store.writeMeta(KdsViewController.metaKey, KdsView.kitchen);
    alarm = RecordingAlarmSink();
    final DateTime now = DateTime.now().toUtc();
    store.insertOrder(
      order(
        'n',
        number: 1,
        station: 'AD',
        dailyCode: 'K12',
        status: PosOrderStatus.placed,
        placed: now,
        changed: now,
      ),
      <PosOrderLine>[line('Ndolé', 1)],
    );
    store.insertOrder(order('p', number: 2, placed: now, changed: now), <PosOrderLine>[line('Koki', 1)]);
  });
  tearDown(() => store.close());

  Future<void> pump(WidgetTester tester, {required bool readOnly}) async {
    tester.view.physicalSize = const Size(2560, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsStoreProvider.overrideWithValue(store),
          kdsAlarmSinkProvider.overrideWithValue(alarm),
          kdsReadOnlyProvider.overrideWithValue(readOnly),
        ],
        child: const KdsApp(),
      ),
    );
    await tester.pump();
  }

  List<KdsTicketCard> cards(WidgetTester tester) =>
      tester.widgetList<KdsTicketCard>(find.byType(KdsTicketCard)).toList();

  testWidgets('tablet KDS and kitchen TV show the same printed ticket', (
    WidgetTester tester,
  ) async {
    final String label = store.findOrder('n')!.ticketLabelOrNull!;
    for (final bool readOnly in <bool>[false, true]) {
      await pump(tester, readOnly: readOnly);
      expect(find.text('Ticket $label'), findsOneWidget);
      expect(find.textContaining('K12'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('read-only: tickets shown, no card actionable, no switch or mute', (WidgetTester tester) async {
    await pump(tester, readOnly: true);
    expect(cards(tester), hasLength(2));
    expect(cards(tester).every((KdsTicketCard c) => c.onPrimaryAction == null && c.onDelete == null), isTrue);
    expect(find.byKey(const Key('kds-switch-view')), findsNothing);
    expect(find.byIcon(Icons.volume_off), findsNothing);
    // The alarm rules still run: a new ticket still rings (on the TV's sink).
    expect(alarm.rung, isNotEmpty);
  });

  testWidgets('the tablet (not read-only) keeps its actions — regression guard', (WidgetTester tester) async {
    await pump(tester, readOnly: false);
    expect(cards(tester).any((KdsTicketCard c) => c.onPrimaryAction != null), isTrue);
    expect(find.byKey(const Key('kds-switch-view')), findsOneWidget);
  });
}
