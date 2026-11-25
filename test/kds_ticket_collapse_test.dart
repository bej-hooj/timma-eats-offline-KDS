import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/kds_app.dart';
import 'package:timma_kds/kds/presentation/widgets/kds_ticket_card.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

/// Owner, 2026-11-24, watching the board fill up on a large screen: *"for
/// space, for better rendering, tickets should have collapse and just show
/// their number, then user expands to see everything ordered inside"*.
void main() {
  late PosStore store;
  late PosEngine engine;

  const PosDeviceIdentity identity = PosDeviceIdentity(
    deviceId: 'kds-cuisine',
    branchId: 'branch-1',
    role: PosDeviceRole.kds,
    label: 'Cuisine',
  );

  MenuSnapshot menu() {
    const MenuSnapshot draft = MenuSnapshot(
      version: 1,
      branchId: 'branch-1',
      declaredProductCount: 1,
      checksum: '',
      products: <SnapshotProduct>[
        SnapshotProduct(
          productId: 'p-jus',
          nameFr: 'Jus de bissap',
          nameEn: 'Bissap juice',
          basePrice: 1000,
          type: 'dish',
          available: true,
        ),
      ],
    );
    return MenuSnapshot(
      version: draft.version,
      branchId: draft.branchId,
      declaredProductCount: draft.declaredProductCount,
      products: draft.products,
      checksum: draft.computeChecksum(),
    );
  }

  setUp(() {
    store = SqlitePosStore.inMemory();
    store.writeIdentity(identity);
    final MenuSnapshot m = menu();
    store.stageSnapshot(m, DateTime.utc(2026, 11, 24));
    store.activateSnapshot(m.version, DateTime.utc(2026, 11, 24));
    engine = PosEngine(store: store, identity: identity);
  });

  tearDown(() => store.close());

  Future<void> show(WidgetTester tester, {int tickets = 1}) async {
    // A board with room for all four lanes, so this test is about the CARD.
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (int i = 0; i < tickets; i++) {
      engine.placeKioskOrder(
        lines: const <PosCartLine>[
          PosCartLine(productId: 'p-jus', quantity: 2),
        ],
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsEngineProvider.overrideWithValue(engine),
          kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
        ],
        child: const KdsApp(),
      ),
    );
    await tester.pump();
  }

  testWidgets('the ticket a cook is working on opens showing its dishes', (
    tester,
  ) async {
    await show(tester);

    // ⚠ Not collapsed by default. A kitchen board whose every ticket must be
    // tapped before it says what to cook is slower than the paper it replaced.
    expect(find.textContaining('Jus'), findsWidgets);
    expect(find.byKey(const Key('kds-ticket-summary')), findsNothing);
  });

  testWidgets('a tap collapses it to its code and a one-line summary', (
    tester,
  ) async {
    await show(tester);

    await tester.tap(find.byType(KdsTicketCard).first);
    await tester.pumpAndSettle();

    // The code stays — it is what a cook calls out.
    expect(find.textContaining('Ticket'), findsWidgets);
    // The dishes go.
    expect(find.textContaining('Jus'), findsNothing);
    // And what is left says enough to decide whether to open it: how much is
    // on it, and what it comes to.
    expect(find.byKey(const Key('kds-ticket-summary')), findsOneWidget);
    expect(find.textContaining('2 articles'), findsOneWidget);
  });

  testWidgets('tapping again opens it, and the action never leaves', (
    tester,
  ) async {
    await show(tester);

    final Finder action = find.descendant(
      of: find.byType(KdsTicketCard),
      matching: find.byType(FilledButton),
    );
    expect(action, findsWidgets, reason: 'expanded');

    await tester.tap(find.byType(KdsTicketCard).first);
    await tester.pumpAndSettle();
    // ⚠ Collapsing must never take the action with it: a cook settles a
    // ticket from the board, not from inside it.
    expect(action, findsWidgets, reason: 'collapsed');

    await tester.tap(find.byType(KdsTicketCard).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Jus'), findsWidgets);
  });

  testWidgets('a crowded lane says there is more below it', (tester) async {
    // Owner, 2026-11-24: *"there are not even scroll indicators in columns
    // for showing other tickets"*. A lane with six tickets and three on
    // screen looked exactly like a lane with three.
    await show(tester, tickets: 6);

    expect(
      find.byType(Scrollbar),
      findsWidgets,
      reason: 'a lane with more tickets than fit must show it',
    );
  });

  testWidgets('a queue collapses behind the two being worked on', (
    tester,
  ) async {
    await show(tester, tickets: 4);

    // ⚠ The whole point of the feature: four open tickets fill a lane and
    // hide the queue. Two open, the rest one line each.
    // ⚠ "At least one", not "exactly two": the lane is a lazy `ListView`, so
    // how many of the four it has built depends on the height, and asserting
    // an exact count would be asserting the viewport rather than the rule.
    // What the rule says is that the queue BEHIND the first two is collapsed.
    expect(
      find.byKey(const Key('kds-ticket-summary')),
      findsAtLeastNWidgets(1),
      reason: 'the tickets behind the first two should be collapsed',
    );
    // And the front of the queue is still open.
    expect(find.textContaining('Jus'), findsWidgets);
  });
}
