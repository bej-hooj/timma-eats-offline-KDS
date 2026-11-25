import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/kds/access/kds_view.dart';
import 'package:timma_kds/kds/access/kds_view_controller.dart';
import 'package:timma_kds/kds/access/kds_view_picker.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/domain/kds_alarm.dart';
import 'package:timma_kds/kds/domain/kds_lanes.dart';
import 'package:timma_kds/kds/kds_app.dart';
import 'package:timma_kds/kds/presentation/widgets/kds_ticket_card.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

/// S5 (owner, 2026-11-25): no login — the KDS opens on « Cuisine » /
/// « Caisse paiement », remembers it, and « Changer de vue » goes back.
void main() {
  group('KdsView.lanesFor', () {
    test('the kitchen never sees À encaisser', () {
      expect(
        KdsView.lanesFor(KdsView.kitchen),
        isNot(contains(KdsLane.counter)),
      );
      expect(KdsView.lanesFor(KdsView.kitchen), contains(KdsLane.newTickets));
      expect(KdsView.lanesFor(KdsView.kitchen), contains(KdsLane.ready));
    });

    test('the till sees À encaisser only', () {
      expect(KdsView.lanesFor(KdsView.cashier), <String>[KdsLane.counter]);
    });

    test('no choice = every lane; order is kept', () {
      expect(KdsView.lanesFor(null), KdsLane.all);
      expect(KdsView.restrict(KdsLane.spine, KdsView.kitchen), <String>[
        KdsLane.newTickets,
        KdsLane.preparing,
        KdsLane.ready,
      ]);
    });

    test('an unknown stored value reads as "not chosen"', () {
      expect(KdsView.parse('manager'), isNull);
      expect(KdsView.parse(''), isNull);
      expect(KdsView.parse(KdsView.cashier), KdsView.cashier);
    });
  });

  late PosStore store;
  late PosEngine engine;
  late RecordingAlarmSink speaker;

  const PosDeviceIdentity identity = PosDeviceIdentity(
    deviceId: 'kds-cuisine',
    branchId: 'branch-1',
    role: PosDeviceRole.kds,
    label: 'Cuisine',
  );

  setUp(() {
    store = SqlitePosStore.inMemory();
    store.writeIdentity(identity);
    const MenuSnapshot draft = MenuSnapshot(
      version: 1,
      branchId: 'branch-1',
      declaredProductCount: 1,
      products: <SnapshotProduct>[
        SnapshotProduct(
          productId: 'p-poulet',
          nameFr: 'Poulet DG',
          nameEn: 'Chicken DG',
          basePrice: 3500,
          type: 'dish',
          available: true,
        ),
      ],
      checksum: '',
    );
    final MenuSnapshot m = MenuSnapshot(
      version: draft.version,
      branchId: draft.branchId,
      declaredProductCount: draft.declaredProductCount,
      products: draft.products,
      checksum: draft.computeChecksum(),
    );
    store.stageSnapshot(m, DateTime.utc(2026, 8, 16));
    store.activateSnapshot(m.version, DateTime.utc(2026, 8, 16));
    engine = PosEngine(store: store, identity: identity);
    speaker = RecordingAlarmSink();
  });

  tearDown(() => store.close());

  ProviderContainer container() {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        kdsEngineProvider.overrideWithValue(engine),
        kdsAlarmSinkProvider.overrideWithValue(speaker),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the choice survives a restart (a new container on the same store)', () {
    container().read(kdsViewProvider.notifier).choose(KdsView.cashier);
    expect(container().read(kdsViewProvider), KdsView.cashier);
  });

  test('Changer de vue forgets the choice', () {
    final ProviderContainer c = container();
    c.read(kdsViewProvider.notifier).choose(KdsView.kitchen);
    c.read(kdsViewProvider.notifier).clear();
    expect(c.read(kdsViewProvider), isNull);
    expect(container().read(kdsViewProvider), isNull);
  });

  test('the till is not rung for a ticket it cannot see', () {
    // A paid ticket sits in Nouvelles: the kitchen register, not the till's.
    final PlacedOrder sale = engine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 1),
      ],
    );
    engine.settleCounterCash(sale.order.clientId);
    final ProviderContainer c = container();
    c.read(kdsViewProvider.notifier).choose(KdsView.cashier);
    c.read(kdsBoardProvider);
    expect(
      speaker.rung,
      isEmpty,
      reason: 'the till must not hear the kitchen alarm',
    );
  });

  test('the kitchen is not rung for an unpaid till ticket', () {
    engine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 1),
      ],
    );
    final ProviderContainer c = container();
    c.read(kdsViewProvider.notifier).choose(KdsView.kitchen);
    c.read(kdsBoardProvider);
    expect(speaker.rung, isNot(contains(KdsAlarmRegister.counter)));

    // Control: with no view chosen, the same ticket DOES ring the till —
    // so the assertion above is the filter, not a silent board.
    final ProviderContainer all = container();
    all.read(kdsViewProvider.notifier).clear();
    all.read(kdsBoardProvider);
    expect(speaker.rung, contains(KdsAlarmRegister.counter));
  });

  Future<void> pump(WidgetTester tester, {Widget? home}) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsEngineProvider.overrideWithValue(engine),
          kdsAlarmSinkProvider.overrideWithValue(speaker),
        ],
        child: KdsApp(home: home),
      ),
    );
    await tester.pump();
  }

  testWidgets('the picker offers both views, and a tap stores it', (
    tester,
  ) async {
    await pump(tester, home: const KdsViewPicker());
    expect(find.text('Cuisine'), findsOneWidget);
    expect(find.text('Caisse paiement'), findsOneWidget);
    await tester.tap(find.byKey(const Key('kds-view-cashier')));
    await tester.pump();
    expect(store.readMeta(KdsViewController.metaKey), KdsView.cashier);
  });

  testWidgets('Caisse paiement draws À encaisser only', (tester) async {
    store.writeMeta(KdsViewController.metaKey, KdsView.cashier);
    engine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 1),
      ],
    );
    await pump(tester);
    expect(find.text('Nouvelles'), findsNothing);
    expect(find.text('Prêtes'), findsNothing);
    expect(find.byType(KdsTicketCard), findsOneWidget);
    expect(find.byKey(const Key('kds-switch-view')), findsOneWidget);
    // The header names the view (seen on the Samsung: it read « Cuisine »).
    expect(find.text('Caisse paiement'), findsOneWidget);
    expect(find.text('Cuisine'), findsNothing);
  });

  testWidgets('Cuisine never draws À encaisser or its tickets', (tester) async {
    store.writeMeta(KdsViewController.metaKey, KdsView.kitchen);
    engine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 1),
      ],
    );
    await pump(tester);
    expect(find.text('Nouvelles'), findsWidgets);
    expect(
      find.byType(KdsTicketCard),
      findsNothing,
      reason: 'an unpaid ticket belongs to the till',
    );
    expect(find.byKey(const Key('kds-delete-ticket')), findsNothing);
  });
}
