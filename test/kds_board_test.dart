import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_core/testing.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/domain/kds_alarm.dart';
import 'package:timma_kds/kds/domain/kds_lanes.dart';
import 'package:timma_kds/kds/kds_app.dart';
import 'package:timma_kds/kds/presentation/board_screen.dart';
import 'package:timma_kds/kds/presentation/widgets/kds_ticket_card.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

/// K5.2–K5.5 — the board, the counter action, the alarm registers and the
/// expiry sweep, against a real engine on an in-memory store.
void main() {
  _headerFitsTests();
  late PosStore store;
  late PosEngine engine;
  late RecordingAlarmSink speaker;

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
    store.stageSnapshot(m, DateTime.utc(2026, 8, 16));
    store.activateSnapshot(m.version, DateTime.utc(2026, 8, 16));
    engine = PosEngine(store: store, identity: identity);
    speaker = RecordingAlarmSink();
  });

  tearDown(() => store.close());

  PlacedOrder ring() => engine.placeKioskOrder(
    lines: const <PosCartLine>[PosCartLine(productId: 'p-poulet', quantity: 1)],
  );

  /// The alarm's speaker is stubbed here for the same reason a camera or a
  /// printer would be: the sink's default is the **real** one, so the wiring
  /// cannot ship silent by accident, and a test that wants quiet has to say so.
  ProviderContainer container({PosEngine? withEngine}) {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        kdsEngineProvider.overrideWithValue(withEngine ?? engine),
        kdsAlarmSinkProvider.overrideWithValue(speaker),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('the counter lane releases tickets to the kitchen', () {
    test('a rung ticket lands unpaid in the counter lane, not in new', () {
      ring();
      final KdsBoardState board = container().read(kdsBoardProvider);
      expect(board.lane(KdsLane.counter), hasLength(1));
      expect(board.lane(KdsLane.newTickets), isEmpty);
    });

    test('one tap takes cash and moves it to new', () {
      final PlacedOrder placed = ring();
      final ProviderContainer c = container();
      c.read(kdsBoardProvider.notifier).settleCash(placed.order.clientId);

      final KdsBoardState board = c.read(kdsBoardProvider);
      expect(board.lane(KdsLane.counter), isEmpty);
      expect(board.lane(KdsLane.newTickets), hasLength(1));

      final PosOrder settled = store.findOrder(placed.order.clientId)!;
      expect(settled.status, PosOrderStatus.placed);
      expect(settled.paymentStatus, PosPaymentStatus.paid);
      expect(
        settled.tender,
        PosTender.cash,
        reason: 'the tablet KDS is cash-only (§7.4) — one button, no picker',
      );
    });

    test('the whole path runs on one button per step', () {
      final PlacedOrder placed = ring();
      final String id = placed.order.clientId;
      final ProviderContainer c = container();
      final KdsBoardController board = c.read(kdsBoardProvider.notifier);

      board.settleCash(id);
      for (final String expected in <String>[
        PosOrderStatus.accepted,
        PosOrderStatus.preparing,
        PosOrderStatus.ready,
        PosOrderStatus.completed,
      ]) {
        board.advance(store.findOrder(id)!);
        expect(store.findOrder(id)!.status, expected);
      }
      expect(
        c.read(kdsBoardProvider).lanes.values.expand((List<PosOrder> l) => l),
        isEmpty,
        reason: 'a completed ticket leaves the board',
      );
    });

    test('a refusal surfaces as a code the cook can see, not a crash', () {
      final PlacedOrder placed = ring();
      final ProviderContainer c = container();
      // Advancing an unpaid ticket is not a legal move; the board must not
      // offer it, and calling it anyway must not throw.
      c.read(kdsBoardProvider.notifier).advance(placed.order);
      expect(
        store.findOrder(placed.order.clientId)!.status,
        PosOrderStatus.pendingPayment,
      );
    });
  });

  group('the 15-minute sweep', () {
    test('nothing stale means nothing reported', () {
      ring();
      ring();
      final ProviderContainer c = container();
      c.read(kdsBoardProvider.notifier).expireStaleUnpaid();
      expect(c.read(kdsBoardProvider).expiredJustNow, 0);
      expect(c.read(kdsBoardProvider).lane(KdsLane.counter), hasLength(2));
    });

    test('the summary count SURVIVES the 5-second refresh', () {
      // The board re-reads every 5 s. A count that lived only in the state
      // object flashed up and was wiped before a cook plating an order could
      // look at the screen — the line exists precisely so tickets cannot
      // vanish from the counter lane unnoticed.
      final ManualClock clock = ManualClock(DateTime.utc(2026, 8, 16, 12));
      final PosEngine timed = PosEngine(
        store: store,
        identity: identity,
        clock: clock,
      );
      timed.placeKioskOrder(
        lines: const <PosCartLine>[
          PosCartLine(productId: 'p-poulet', quantity: 1),
        ],
      );
      clock.advance(const Duration(minutes: 16));

      final ProviderContainer c = container(withEngine: timed);
      final KdsBoardController board = c.read(kdsBoardProvider.notifier);

      board.expireStaleUnpaid();
      expect(c.read(kdsBoardProvider).expiredJustNow, 1);

      board.refresh();
      expect(
        c.read(kdsBoardProvider).expiredJustNow,
        1,
        reason: 'a refresh must not wipe the line before anyone read it',
      );

      board.acknowledgeExpired();
      expect(
        c.read(kdsBoardProvider).expiredJustNow,
        0,
        reason: 'it is dismissed by a person, never by a timer',
      );
    });
  });

  group('the alarm has three registers, and they do not share a seen-set', () {
    late KdsAlarm alarm;
    final DateTime t0 = DateTime.utc(2026, 8, 16, 12);

    setUp(() => alarm = KdsAlarm());

    Map<String, List<PosOrder>> lanesWith(List<PosOrder> unclaimed) =>
        KdsLane.board(unclaimed, now: t0);

    /// A ticket that has been **paid** at the counter, so it sits in
    /// *Nouvelles* rather than *À encaisser*. The two lanes are what the two
    /// repeating registers watch, so a test about one of them has to be able
    /// to produce the other.
    PosOrder cooked() {
      final PlacedOrder placed = ring();
      engine.settleCounterCash(placed.order.clientId);
      return engine.store
          .openOrders()
          .firstWhere((PosOrder o) => o.clientId == placed.order.clientId);
    }

    test('an unpaid ticket sounds the counter register', () {
      final PlacedOrder placed = ring();
      final KdsAlarmCue? cue = alarm.evaluate(
        lanes: lanesWith(<PosOrder>[placed.order]),
        now: t0,
      );
      expect(
        cue?.register,
        KdsAlarmRegister.counter,
        reason: 'owner 2026-11-23: À encaisser must not sound like Nouvelles',
      );
      expect(cue?.count, 1);
    });

    test('a paid ticket waiting to be cooked sounds the waiting register', () {
      final KdsAlarmCue? cue = alarm.evaluate(
        lanes: lanesWith(<PosOrder>[cooked()]),
        now: t0,
      );
      expect(cue?.register, KdsAlarmRegister.waiting);
    });

    test('the counter wins a tie, and the loser is NOT swallowed', () {
      final PlacedOrder unpaid = ring();
      final PosOrder paid = cooked();
      final Map<String, List<PosOrder>> both = lanesWith(<PosOrder>[
        unpaid.order,
        paid,
      ]);

      // ⚠ One speaker. Mixing two alarms yields a noise that is neither, so
      // they take precedence — the counter first, because a person is standing
      // there holding cash.
      expect(
        alarm.evaluate(lanes: both, now: t0)?.register,
        KdsAlarmRegister.counter,
      );
      // ⚠ The whole point: the register that lost did not have its arrival
      // recorded, so it sounds on the very next refresh rather than never. A
      // register a busier lane can starve is one the kitchen learns to
      // distrust.
      expect(
        alarm
            .evaluate(lanes: both, now: t0.add(const Duration(seconds: 5)))
            ?.register,
        KdsAlarmRegister.waiting,
      );
    });

    test('each register keeps its own nag clock', () {
      final PlacedOrder unpaid = ring();
      final PosOrder paid = cooked();
      final Map<String, List<PosOrder>> both = lanesWith(<PosOrder>[
        unpaid.order,
        paid,
      ]);
      alarm.evaluate(lanes: both, now: t0); // counter
      alarm.evaluate(lanes: both, now: t0.add(const Duration(seconds: 5)));

      // Both have now sounded once. Neither may sound again before its own
      // interval — a shared clock would let one lane's arrival reset the
      // other's nag, which is the v1.15 seen-set bug wearing a different hat.
      expect(
        alarm.evaluate(lanes: both, now: t0.add(const Duration(seconds: 40))),
        isNull,
      );
      expect(
        alarm
            .evaluate(lanes: both, now: t0.add(const Duration(seconds: 65)))
            ?.register,
        KdsAlarmRegister.counter,
      );
    });

    test('one button silences every register', () {
      final PlacedOrder unpaid = ring();
      final PosOrder paid = cooked();
      final Map<String, List<PosOrder>> both = lanesWith(<PosOrder>[
        unpaid.order,
        paid,
      ]);
      alarm.evaluate(lanes: both, now: t0);
      alarm.mute();
      expect(
        alarm.evaluate(
          lanes: both,
          now: t0.add(const Duration(seconds: 5)),
        ),
        isNull,
        reason:
            'Couper l\'alarme is one button on a tablet; silencing only the '
            'register that happened to be playing leaves the kitchen tapping '
            'at a board that keeps making noise',
      );
      expect(alarm.muted, isTrue);
    });

    test('it does not re-sound before the nag interval, and does after', () {
      final PlacedOrder placed = ring();
      final Map<String, List<PosOrder>> lanes = lanesWith(<PosOrder>[
        placed.order,
      ]);

      expect(
        alarm.evaluate(lanes: lanes, now: t0)?.register,
        KdsAlarmRegister.counter,
      );
      expect(
        alarm.evaluate(lanes: lanes, now: t0.add(const Duration(seconds: 30))),
        isNull,
        reason: 'a nag that fires every frame is noise the kitchen tunes out',
      );
      expect(
        alarm
            .evaluate(lanes: lanes, now: t0.add(KdsSla.reminderEvery))
            ?.register,
        KdsAlarmRegister.counter,
      );
    });

    test('the nag stops on its own when the lane empties', () {
      final PlacedOrder placed = ring();
      alarm.evaluate(lanes: lanesWith(<PosOrder>[placed.order]), now: t0);
      expect(
        alarm.evaluate(lanes: lanesWith(<PosOrder>[]), now: t0),
        isNull,
        reason: 'reminderEvery is a nag interval, not a duration',
      );
    });

    test('muting silences the current run but never the next order', () {
      final PlacedOrder first = ring();
      alarm.evaluate(lanes: lanesWith(<PosOrder>[first.order]), now: t0);
      alarm.mute();
      expect(
        alarm.evaluate(
          lanes: lanesWith(<PosOrder>[first.order]),
          now: t0.add(KdsSla.reminderEvery),
        ),
        isNull,
      );

      final PlacedOrder second = ring();
      final KdsAlarmCue? cue = alarm.evaluate(
        lanes: lanesWith(<PosOrder>[first.order, second.order]),
        now: t0.add(const Duration(seconds: 70)),
      );
      expect(
        cue?.register,
        KdsAlarmRegister.counter,
        reason:
            'muting the current nag must not swallow the NEXT order — a '
            'kitchen that can silence itself for the night loses tickets',
      );
      expect(alarm.muted, isFalse);
    });

    test('an emptied lane clears the mute', () {
      final PlacedOrder placed = ring();
      alarm.evaluate(lanes: lanesWith(<PosOrder>[placed.order]), now: t0);
      alarm.mute();
      alarm.evaluate(lanes: lanesWith(<PosOrder>[]), now: t0);
      expect(alarm.muted, isFalse);
    });
  });

  group('card identity — §1.6', () {
    testWidgets('take cash and already paid are never confusable', (
      tester,
    ) async {
      final PlacedOrder placed = ring();
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kdsEngineProvider.overrideWithValue(engine),
            kdsAlarmSinkProvider.overrideWithValue(speaker),
          ],
          child: const KdsApp(),
        ),
      );
      await tester.pump();

      // Unpaid: the money state says so and the button asks for cash.
      expect(find.text('À encaisser'), findsWidgets);
      expect(find.text('Borne'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Encaisser en espèces'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Encaisser en espèces'),
      );
      await tester.pump();

      // Paid: the badge flips and the cash button is gone for good.
      expect(find.text('Payé'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Encaisser en espèces'),
        findsNothing,
        reason:
            'a paid ticket must never offer a cash button again — that is '
            'how a customer gets asked to pay twice',
      );
      expect(find.widgetWithText(FilledButton, 'Accepter'), findsOneWidget);
      expect(find.byType(KdsTicketCard), findsOneWidget);
      expect(placed.order.ticketNumber, isNotNull);
    });
  });
}

/// The header holds a logo, a title, an expiry line, an offline badge and
/// *Couper l'alarme* on one row.
///
/// ⚠ It overflowed by 44 px on the simulator the first time the expiry line and
/// the alarm were on screen together — the hazard stripe was drawn straight
/// through the mute button. A `Row` with a `Spacer` does not protect anything:
/// the non-flexible children take their natural widths first, and French is
/// longer than English on every one of these strings.
void _headerFitsTests() {
  group('the board header at the real board width', () {
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
      store.stageSnapshot(m, DateTime.utc(2026, 8, 19));
      store.activateSnapshot(m.version, DateTime.utc(2026, 8, 19));
      engine = PosEngine(store: store, identity: identity);
      speaker = RecordingAlarmSink();
    });

    tearDown(() => store.close());

    testWidgets('the expiry line and the alarm coexist, in French', (
      tester,
    ) async {
      // The iPhone the cuisine runs on, landscape: 844 x 390 dp.
      tester.view.physicalSize = const Size(2532, 1170);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // One unclaimed ticket puts the alarm on screen…
      engine.placeKioskOrder(
        lines: const <PosCartLine>[
          PosCartLine(productId: 'p-poulet', quantity: 1),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kdsEngineProvider.overrideWithValue(engine),
            kdsAlarmSinkProvider.overrideWithValue(speaker),
          ],
          child: const KdsApp(),
        ),
      );
      await tester.pump();

      // …and the sweep's summary line beside it is what tipped it over.
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(KdsBoardScreen)),
      );
      container.read(kdsBoardProvider.notifier).expireStaleUnpaid();
      await tester.pump();

      expect(find.text('Couper l\'alarme'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason:
            'the header overflowed with the expiry line and the alarm '
            'both on screen — the stripe went through the mute button',
      );
    });
  });
}
