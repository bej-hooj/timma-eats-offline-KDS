import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_core/testing.dart';
import 'package:pos_link/pos_link.dart';
import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/domain/kds_lanes.dart';
import 'package:timma_kds/kds/kds_app.dart';
import 'package:timma_kds/kds/presentation/widgets/kds_ticket_card.dart';
import 'package:timma_kds/kds/state/kds_board.dart';
import 'package:timma_kds/kds/theme/kds_scale.dart';

/// **A cook cannot cook a total.**
///
/// Owner, 2026-08-19: *"the ticket recieved on the cuisine doesnt currently
/// contain the dishes and every details about… the tickets should contain all
/// information the client took"*. Right: the card rendered a ticket number, two
/// chips and an amount. The lines had been arriving on the wire since K3 —
/// `BoardOrder` carries them and the merge writes them locally — and the card
/// threw them away, so the kitchen read the board and then walked to the
/// counter to ask what was in the order.
void main() {
  _theActionIsAlwaysOnScreen();
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
      declaredProductCount: 2,
      products: <SnapshotProduct>[
        SnapshotProduct(
          productId: 'p-poulet',
          nameFr: 'Poulet DG',
          nameEn: 'Chicken DG',
          basePrice: 4500,
          type: 'dish',
          available: true,
          variants: <SnapshotVariant>[
            SnapshotVariant(
              variantId: 'v-grand',
              nameFr: 'Grand',
              nameEn: 'Large',
              priceDelta: 1000,
            ),
          ],
          optionGroups: <SnapshotOptionGroup>[
            SnapshotOptionGroup(
              groupId: 'g-acc',
              nameFr: 'Accompagnement',
              nameEn: 'Side',
              minSelect: 1,
              maxSelect: 2,
              options: <SnapshotOption>[
                SnapshotOption(
                  optionId: 'o-plantain',
                  nameFr: 'Plantain',
                  nameEn: 'Plantain',
                  priceDelta: 500,
                  maxQty: 1,
                  available: true,
                ),
                SnapshotOption(
                  optionId: 'o-piment',
                  nameFr: 'Sauce piquante',
                  nameEn: 'Hot sauce',
                  priceDelta: 0,
                  maxQty: 1,
                  available: true,
                ),
              ],
            ),
          ],
        ),
        SnapshotProduct(
          productId: 'p-jus',
          nameFr: 'Jus de gingembre',
          nameEn: 'Ginger juice',
          basePrice: 1000,
          type: 'drink',
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
    store.stageSnapshot(m, DateTime.utc(2026, 8, 19));
    store.activateSnapshot(m.version, DateTime.utc(2026, 8, 19));
    engine = PosEngine(store: store, identity: identity);
  });

  tearDown(() => store.close());

  testWidgets('the ticket names every dish, its size and its options', (
    tester,
  ) async {
    // The cuisine's real shape: an 844 x 390 board in landscape.
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    engine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(
          productId: 'p-poulet',
          quantity: 2,
          variantId: 'v-grand',
          options: <PosCartOption>[
            PosCartOption(optionId: 'o-plantain'),
            PosCartOption(optionId: 'o-piment'),
          ],
        ),
        PosCartLine(productId: 'p-jus', quantity: 1),
      ],
    );

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

    // The dishes, in French, with their quantities.
    expect(find.text('Poulet DG'), findsOneWidget);
    expect(find.text('2 ×'), findsOneWidget);
    expect(find.text('Jus de gingembre'), findsOneWidget);
    expect(find.text('1 ×'), findsOneWidget);

    // The size, and both chosen options — the detail a cook needs to plate it.
    expect(find.text('Grand'), findsOneWidget);

    /*
     * ⚠ ONE LINE PER OPTION since Q69, not a middot-joined sentence. Three
     * facts run together wrap across a card read at arm's length, and the
     * answer a cook needs ends up on the second line of a grey run.
     *
     * This order was composed ON the borne, which has no modifier-group
     * picker, so it takes the FALLBACK path: the flat list of what was chosen,
     * which is the only thing such a row can honestly say.
     */
    expect(find.text('Plantain'), findsOneWidget);
    expect(find.text('Sauce piquante'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the ticket says WHICH borne, not just a number', (tester) async {
    /*
     * ⚠ This board is exactly where two bornes meet.
     *
     * `allocateTicketNumber` counts per till and restarts at 1 at the Douala
     * boundary, so a branch running two bornes sends two different #1s to one
     * kitchen — and until migration 54 the number did not even reach a board
     * fed by another borne, so the card omitted the line entirely and a cook
     * had nothing to call out.
     */
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    engine.placeKioskOrder(
      lines: const <PosCartLine>[PosCartLine(productId: 'p-jus', quantity: 1)],
    );

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

    final String station = stationCodeFor(identity.deviceId);
    // Four characters since 2026-11-23 (owner): station + a permutation of the
    // sequence, no separator. Derived through the same function the card uses,
    // never retyped.
    final String code = '$station${ticketSequenceCode(1)}';
    expect(code, matches(RegExp(r'^[A-Z0-9]{4}$')));
    expect(find.text('Ticket $code'), findsOneWidget);
    expect(
      find.text('Ticket 1'),
      findsNothing,
      reason: 'a bare number is ambiguous the moment there are two tills',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an order from before stations shows its bare number', (
    tester,
  ) async {
    // Never an invented station: sending a cook to the wrong borne's customer
    // is worse than a number with no letter on it.
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    store.insertOrder(
      PosOrder(
        clientId: 'legacy-1',
        branchId: 'branch-1',
        origin: PosOrderOrigin.remote,
        source: PosOrderSource.kiosk,
        mode: PosOrderMode.pickup,
        status: PosOrderStatus.placed,
        paymentStatus: PosPaymentStatus.unpaid,
        paymentMethod: PosPaymentMethod.payAtCounter,
        deviceSeq: 0,
        ticketNumber: 9,
        subtotal: 1000,
        discount: 0,
        deliveryFee: 0,
        total: 1000,
        placedAtDevice: DateTime.utc(2026, 8, 19, 12),
        statusChangedAt: DateTime.utc(2026, 8, 19, 12),
      ),
      const <PosOrderLine>[],
    );

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

    expect(find.text('Ticket 09'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// What the real board showed on 2026-11-23, screenshotted on the Samsung:
  /// a ticket synced down from the cloud, carrying **"142411 min"**, no ticket
  /// number at all, and not one dish — a card that reads as a broken app.
  group('a ticket that came down from the cloud', () {
    void insertCloudTicket({
      String? dailyCode = 'K14',
      String? orderCode = 'TME-2026-0007',
      DateTime? placedAt,
    }) {
      final DateTime at = placedAt ?? DateTime.utc(2026, 8, 19, 12);
      store.insertOrder(
        PosOrder(
          clientId: 'cloud-1',
          branchId: 'branch-1',
          origin: PosOrderOrigin.remote,
          source: PosOrderSource.app,
          mode: PosOrderMode.pickup,
          status: PosOrderStatus.ready,
          paymentStatus: PosPaymentStatus.paid,
          paymentMethod: PosPaymentMethod.payAtCounter,
          deviceSeq: 0,
          // ⚠ The whole point: a cloud ticket was not printed by any borne
          // here, so it has NO local number.
          subtotal: 1000,
          discount: 0,
          deliveryFee: 0,
          total: 1000,
          placedAtDevice: at,
          statusChangedAt: at,
          dailyCode: dailyCode,
          orderCode: orderCode,
        ),
        const <PosOrderLine>[],
      );
    }

    Future<void> show(WidgetTester tester) async {
      // ⚠ A board wide enough for all four lanes. These tests are about what
      // a CARD says, not about how many lanes fit: since the lane floor went
      // to 280 dp (so a card is readable at all), the Samsung's 868 dp board
      // scrolls sideways and the *Prêtes* lane is off screen — which would
      // fail these for a reason that has nothing to do with the card.
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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

    testWidgets('is identified by the kitchen code the server minted', (
      tester,
    ) async {
      insertCloudTicket();
      await show(tester);

      // Before this, the card showed nothing a cook could call out: the
      // identity line was behind `if (ticketLabelOrNull != null)`.
      expect(find.text('Ticket K14'), findsOneWidget);
    });

    testWidgets('falls back to the order code, never to nothing', (
      tester,
    ) async {
      insertCloudTicket(dailyCode: null);
      await show(tester);

      expect(find.text('Ticket TME-2026-0007'), findsOneWidget);
    });

    testWidgets('says the detail has not arrived, instead of looking empty', (
      tester,
    ) async {
      insertCloudTicket();
      await show(tester);

      // A cook cannot tell "nothing ordered" from "the lines never came" on a
      // blank card, and one of those is a bug they should report.
      expect(find.byKey(const Key('kds-lines-pending')), findsOneWidget);
    });

    testWidgets('shows its age in HOURS, never 142411 min', (tester) async {
      // Three months old, which is what a stale cloud row actually is.
      insertCloudTicket(
        placedAt: DateTime.now().toUtc().subtract(const Duration(days: 98)),
      );
      await show(tester);

      expect(
        find.textContaining('min'),
        findsNothing,
        reason: 'minutes is a unit for tens, and this is six figures of them',
      );
      expect(
        find.textContaining(RegExp(r'\+\d+'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('a fresh ticket still reads in minutes', (tester) async {
      insertCloudTicket(
        placedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 7)),
      );
      await show(tester);

      // The switch is at three hours; below it minutes are what a cook wants.
      expect(find.text('7 min'), findsOneWidget);
    });
  });

  /// Owner, 2026-11-23: *"kitchen and born should fit any size cause it could
  /// be displayed on tv. so RESPONSIVENESS"*.
  ///
  /// A television reports its pixels at a ratio of 1, so the board is handed a
  /// logical width four times anything a tablet gives it — and at the other
  /// end a 640 dp board has to carry the same four lanes. The text scale is in
  /// here because ignoring it is exactly what kept *En préparation* truncated
  /// through three attempts: the kitchen Samsung is set to 1.1.
  for (final (String name, Size size, double ratio, double scale)
      in <(String, Size, double, double)>[
        ('television 1080p', Size(1920, 1080), 1.0, 1.0),
        ('television 4K', Size(3840, 2160), 1.0, 1.0),
        ('Samsung landscape', Size(2280, 1080), 2.625, 1.1),
        ('Samsung at 1.3', Size(2280, 1080), 2.625, 1.3),
        ('budget 7-inch', Size(1280, 800), 2.0, 1.0),
        ('portrait, mid-rotation', Size(1080, 2280), 2.625, 1.0),
      ]) {
    testWidgets('the board holds together — $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.reset);

      engine.placeKioskOrder(
        lines: const <PosCartLine>[
          PosCartLine(productId: 'p-jus', quantity: 2),
        ],
      );

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: ProviderScope(
            overrides: [
              kdsEngineProvider.overrideWithValue(engine),
              kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
            ],
            child: const KdsApp(),
          ),
        ),
      );
      await tester.pump();

      // An overflow throws here, which is the whole point: the board is the
      // screen nobody is watching when it breaks.
      expect(tester.takeException(), isNull, reason: 'overflow at $name');
      // And it is still a board: the ticket is on it.
      expect(find.byType(KdsTicketCard), findsWidgets, reason: name);

      // ⚠⚠ And the ticket is READABLE, which "no overflow" never said.
      // Measured on the real pair 2026-11-24: at a 183 dp lane the card drew
      // its chips and its action button and nothing else — no code, no dish,
      // no total — and every test here passed. A board that shows a cook
      // neither what to cook nor which ticket it is has failed at its only
      // job, so the dish itself is the assertion.
      expect(
        find.textContaining('Jus'),
        findsWidgets,
        reason: 'the ticket showed no dish at $name',
      );
    });
  }

  /// Owner, 2026-11-24: *"i hope the responsiveness of the kitchen won't
  /// necessitate a scroll on larger screen to show all columns"*, and *"i hope
  /// it is 100% responsive even on tv width screens"*.
  for (final (String name, Size size, double ratio) in <(String, Size, double)>[
    ('Windows PC 1280x800', Size(1280, 800), 1.0),
    ('television 1080p', Size(1920, 1080), 1.0),
    ('television 4K', Size(3840, 2160), 1.0),
  ]) {
    testWidgets('all four lanes are on screen at once — $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.reset);

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

      // ⚠ Not "the widget exists" — the August pairing bug passed that while
      // the control was off screen. Every lane's heading has to be INSIDE the
      // viewport, with nothing to swipe.
      final double width = size.width / ratio;
      for (final String lane in <String>[
        'À encaisser',
        'Nouvelles',
        'En préparation',
        'Prêtes',
      ]) {
        final Finder title = find.text(lane);
        expect(title, findsWidgets, reason: '$lane missing at $name');
        final Rect rect = tester.getRect(title.first);
        expect(
          rect.right,
          lessThanOrEqualTo(width + 0.5),
          reason: '$lane ran ${rect.right - width} dp off the right at $name',
        );
        expect(rect.left, greaterThanOrEqualTo(-0.5), reason: '$lane at $name');
      }
    });
  }

  testWidgets('a television board fills its width and prints large', (
    tester,
  ) async {
    // ⚠ Rendered at a 1080p TV geometry on 2026-11-25 (2 280 x 1 080 dp, on a
    // phone with its density dropped): four 320 dp lanes took 1 328 dp and
    // left about 950 of empty cream down the right, with tablet-sized type in
    // the corner of a room-sized screen. A kitchen board is read from metres
    // away.
    tester.view.physicalSize = const Size(2280, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    engine.placeKioskOrder(
      lines: const <PosCartLine>[PosCartLine(productId: 'p-jus', quantity: 2)],
    );

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

    // The lanes use the board: from the left edge of the first to the right
    // edge of the last is most of the width, not a third of it.
    final Rect first = tester.getRect(find.text('À encaisser').first);
    final Rect last = tester.getRect(find.text('Prêtes').first);
    expect(
      last.right - first.left,
      greaterThan(2280 * 0.6),
      reason: 'the lanes huddled in ${last.right - first.left} dp of 2280',
    );

    // And the dish is printed at the large step, not the tablet one.
    final Finder dish = find.textContaining('Jus').first;
    expect(
      (tester.widget<Text>(dish).style?.fontSize ?? 0),
      greaterThan(KdsScale.bodySize),
      reason: 'a wall board should not print at counter size',
    );
  });

  testWidgets('a ticket that ARRIVED FROM THE BORNE shows its dishes', (
    tester,
  ) async {
    // ⚠⚠ The real path, which every other test here skips: the orders on a
    // kitchen board are not placed on it, they are MERGED into it from a
    // board frame the borne publishes. Measured on the real pair 2026-11-24
    // with production builds: the card showed its chips and its action button
    // and nothing between them — no code, no dish, no total.
    tester.view.physicalSize = const Size(2280, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    // The BORNE's own store and engine, as the hub has them.
    final PosStore borneStore = SqlitePosStore.inMemory();
    addTearDown(borneStore.close);
    const PosDeviceIdentity borneIdentity = PosDeviceIdentity(
      deviceId: 'borne-gm92',
      branchId: 'branch-1',
      role: PosDeviceRole.kiosk,
      label: 'Borne',
    );
    borneStore.writeIdentity(borneIdentity);
    final MenuSnapshot m = menu();
    borneStore.stageSnapshot(m, DateTime.utc(2026, 11, 24));
    borneStore.activateSnapshot(m.version, DateTime.utc(2026, 11, 24));
    final PosEngine borne = PosEngine(
      store: borneStore,
      identity: borneIdentity,
    );
    borne.placeKioskOrder(
      lines: const <PosCartLine>[PosCartLine(productId: 'p-jus', quantity: 2)],
    );

    // …published as a board frame, through the wire, and merged on the KDS.
    final BoardSnapshot frame = BoardSnapshot.fromWire(
      BoardSnapshot.fromStore(store: borneStore, clock: ManualClock()).toWire(),
    );
    frame.applyTo(engine);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
        child: ProviderScope(
          overrides: [
            kdsEngineProvider.overrideWithValue(engine),
            kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
          ],
          child: const KdsApp(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Jus'),
      findsWidgets,
      reason:
          'a ticket from the borne showed no dish — a cook cannot cook a '
          'total',
    );
  });

  testWidgets('a cook can READ the ticket on the kitchen Samsung', (
    tester,
  ) async {
    // ⚠⚠ Measured on the real pair 2026-11-24, production builds, a live
    // order from the borne: the card rendered its chips and its action button
    // and NOTHING ELSE. No ticket code, no dish, "Borne" wrapped to "Born/e"
    // and "Encaisser en espèce" to three lines. A kitchen board that shows a
    // cook neither what to cook nor which ticket it is has failed at its only
    // job, and "no overflow" passed throughout.
    tester.view.physicalSize = const Size(2280, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    engine.placeKioskOrder(
      lines: const <PosCartLine>[PosCartLine(productId: 'p-jus', quantity: 2)],
    );

    await tester.pumpWidget(
      MediaQuery(
        // The kitchen Samsung's own setting.
        data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
        child: ProviderScope(
          overrides: [
            kdsEngineProvider.overrideWithValue(engine),
            kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
          ],
          child: const KdsApp(),
        ),
      ),
    );
    await tester.pump();

    // The dish. This is what a cook cooks from.
    expect(
      find.textContaining('Jus'),
      findsWidgets,
      reason: 'the ticket showed no dish at all',
    );
    // And the handle they call it out by.
    expect(
      find.textContaining('Ticket'),
      findsWidgets,
      reason: 'the ticket showed no code',
    );
  });

  testWidgets('the lanes are the take-away spine, not six fixed columns', (
    tester,
  ) async {
    // Wide enough that all four are on screen at once — this is about WHICH
    // lanes the board has, not how many fit. On a narrower board they are all
    // still there, behind a sideways scroll (see the responsive sweep).
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    engine.placeKioskOrder(
      lines: const <PosCartLine>[PosCartLine(productId: 'p-jus', quantity: 1)],
    );

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

    // "À encaisser" is both a lane title and a card's money-state chip, so it
    // legitimately appears more than once.
    expect(find.text('À encaisser'), findsWidgets);
    for (final String lane in <String>[
      'Nouvelles',
      'En préparation',
      'Prêtes',
    ]) {
      expect(find.text(lane), findsOneWidget, reason: '$lane is the spine');
    }

    // ⚠ Neither of these can hold a kiosk order. `PosOrder` carries no fire
    // time, so *Programmées* can never fill at all; and a customer standing at
    // the counter is not a delivery. Two permanently empty 320 dp columns on an
    // 844 dp board is a cook scrolling past nothing to reach the work.
    expect(find.text('Programmées'), findsNothing);
    expect(find.text('En livraison'), findsNothing);

    // ⚠ And all four are on screen at once. A fixed 320 dp column fitted 2.6
    // lanes on this board, so a cook had to scroll horizontally to see
    // *Prêtes* — the lane that says an order is ready to hand over.
    // ⚠ Measured on the COLUMN, not on the title. A title sits at the start of
    // its column, so its right edge fits long after the column itself has run
    // off the screen — which is exactly how the first version of this
    // assertion passed while the device showed *Prêtes* clipped in half.
    final double boardWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final Finder lastLane = find.ancestor(
      of: find.text('Prêtes'),
      matching: find.byType(Container),
    );
    expect(
      tester.getRect(lastLane.first).right,
      lessThanOrEqualTo(boardWidth),
      reason:
          'the last spine lane must be whole on screen — a cook cannot '
          'scroll to find out an order is ready',
    );
    expect(KdsScale.spineLaneCount, KdsLane.spine.length);
  });

  test('a lane that holds something is always drawn', () {
    final Map<String, List<PosOrder>> lanes = <String, List<PosOrder>>{
      for (final String lane in KdsLane.all) lane: const <PosOrder>[],
    };
    expect(KdsLane.visible(lanes), KdsLane.spine);

    final PlacedOrder delivered = engine.placeKioskOrder(
      lines: const <PosCartLine>[PosCartLine(productId: 'p-jus', quantity: 1)],
    );
    lanes[KdsLane.outForDelivery] = <PosOrder>[delivered.order];
    expect(
      KdsLane.visible(lanes),
      contains(KdsLane.outForDelivery),
      reason: 'a lane appears the moment it has work, and keeps board order',
    );
    expect(
      KdsLane.visible(lanes).indexOf(KdsLane.outForDelivery),
      KdsLane.visible(lanes).length - 1,
      reason: 'left-to-right reading is a promise — lanes never swap places',
    );
  });

  testWidgets('a removal is its own line, in the error colour, in CAPITALS', (
    tester,
  ) async {
    /*
     * R2 / Stage 3d. The three assertions here are one rule: **a cook reads a
     * modifier and a removal in opposite directions.** A modifier is something
     * to add; a removal is something to withhold. Printed together, in the same
     * weight, "sans oignon" reads as "add onion" — and this board is skimmed at
     * arm's length by somebody already cooking.
     */
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // A CLOUD order, because the borne has no ingredient picker — a removal can
    // only ever arrive from the app or the website.
    engine.mergeRemoteOrder(
      PosOrder(
        clientId: 'c-remote-1',
        branchId: 'branch-1',
        origin: PosOrderOrigin.remote,
        source: PosOrderSource.app,
        mode: PosOrderMode.pickup,
        status: PosOrderStatus.placed,
        paymentStatus: PosPaymentStatus.paid,
        paymentMethod: PosPaymentMethod.mobileMoney,
        deviceSeq: 0,
        subtotal: 4500,
        discount: 0,
        deliveryFee: 0,
        total: 4500,
        placedAtDevice: DateTime.utc(2026, 8, 26, 12),
        statusChangedAt: DateTime.utc(2026, 8, 26, 12),
        serverOrderId: 'srv-remote-1',
        orderCode: 'TM-100300',
        ticketNumber: 42,
      ),
      const <PosOrderLine>[
        PosOrderLine(
          lineNo: 0,
          productId: 'p-poulet',
          nameFr: 'Poulet DG',
          nameEn: 'Chicken DG',
          unitPrice: 4500,
          quantity: 1,
          lineTotal: 4500,
          modifiers: <PosLineModifier>[
            PosLineModifier(
              optionId: 'o-plantain',
              nameFr: 'Plantain',
              nameEn: 'Plantain',
              priceDelta: 500,
              quantity: 1,
            ),
          ],
          removedIngredients: <PosRemovedIngredient>[
            PosRemovedIngredient(
              id: 'ing-onion',
              nameFr: 'Oignon',
              nameEn: 'Onion',
            ),
          ],
        ),
      ],
    );

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

    // 1. It is said, in words a cook cannot read as an instruction to ADD.
    expect(find.text('SANS OIGNON'), findsOneWidget);

    // 2. It is NOT in the modifier line.
    expect(find.text('Plantain'), findsOneWidget);
    expect(find.text('Plantain · SANS OIGNON'), findsNothing);

    // 3. It is drawn in the error colour and heavier than the options beside
    //    it — the only thing on the card that changes what the cook must NOT
    //    do.
    final Text removed = tester.widget<Text>(
      find.byKey(const Key('kds-line-removed')),
    );
    expect(removed.style?.color, AppColors.error);
    expect(removed.style?.fontWeight, FontWeight.w800);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '⚠⚠ Q69 — a group that was OFFERED and DECLINED is on the ticket',
    (tester) async {
      /*
       * Owner, 2026-09-02, holding the ticket for TM-100136: *"ALl the
       * accompagnement. pepper or not and every informations. Do the same on
       * the Offline KDS"*.
       *
       * ⚠⚠ **This is the case the flat modifier list cannot express.** A dish
       * that offered *Piment* and was given none produces exactly the same
       * `modifiers` array as a dish that never had a Piment group — so a board
       * printing only the chosen options is silent about both, and a cook
       * cannot tell "they said no chilli" from "nobody asked". Migration 63
       * carries the question as well as the answer; migration 64 carries it to
       * this tablet.
       *
       * ⚠ A CLOUD order, because the borne has no group picker yet — the same
       * reason the removal test above uses one.
       */
      tester.view.physicalSize = const Size(2532, 1170);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      engine.mergeRemoteOrder(
        PosOrder(
          clientId: 'c-remote-q69',
          branchId: 'branch-1',
          origin: PosOrderOrigin.remote,
          source: PosOrderSource.app,
          mode: PosOrderMode.pickup,
          status: PosOrderStatus.placed,
          paymentStatus: PosPaymentStatus.paid,
          paymentMethod: PosPaymentMethod.mobileMoney,
          deviceSeq: 0,
          subtotal: 5100,
          discount: 0,
          deliveryFee: 0,
          total: 5100,
          placedAtDevice: DateTime.utc(2026, 9, 2, 12),
          statusChangedAt: DateTime.utc(2026, 9, 2, 12),
          serverOrderId: 'srv-remote-q69',
          orderCode: 'TM-100400',
          ticketNumber: 43,
        ),
        const <PosOrderLine>[
          PosOrderLine(
            lineNo: 0,
            productId: 'p-poulet',
            nameFr: 'Poulet DG',
            nameEn: 'Chicken DG',
            unitPrice: 5100,
            quantity: 1,
            lineTotal: 5100,
            modifiers: <PosLineModifier>[
              PosLineModifier(
                optionId: 'o-plantain',
                nameFr: 'Plantain mûr',
                nameEn: 'Ripe plantain',
                priceDelta: 100,
                quantity: 2,
              ),
            ],
            modifierGroups: <PosLineGroup>[
              PosLineGroup(
                groupId: 'g-side',
                nameFr: 'Accompagnement',
                nameEn: 'Side',
                options: <PosLineModifier>[
                  PosLineModifier(
                    optionId: 'o-plantain',
                    nameFr: 'Plantain mûr',
                    nameEn: 'Ripe plantain',
                    priceDelta: 100,
                    quantity: 2,
                  ),
                ],
              ),
              // The whole point: asked, and answered "nothing".
              PosLineGroup(
                groupId: 'g-chili',
                nameFr: 'Piment',
                nameEn: 'Chili',
              ),
            ],
          ),
        ],
      );

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

      // 1. The answered group, with the quantity — `max_qty` options are
      //    priced per unit, so "×2" is the plate AND the bill.
      expect(find.text('Accompagnement : 2 × Plantain mûr'), findsOneWidget);

      // 2. ⚠⚠ The DECLINED group, said out loud.
      expect(
        find.text('Piment : AUCUN'),
        findsOneWidget,
        reason:
            'printing nothing for Piment is indistinguishable from a dish '
            'that never offered it',
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a line with nothing removed draws no removal row at all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    engine.placeKioskOrder(
      lines: const <PosCartLine>[PosCartLine(productId: 'p-jus', quantity: 1)],
    );

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

    expect(find.byKey(const Key('kds-line-removed')), findsNothing);
  });
}

/// ⚠⚠ **A control a cook cannot reach is a control that does not exist.**
///
/// Seen on the real pair, 2026-11-22: *Ticket 01* arrived from the borne on
/// the Samsung the kitchen runs on — **411 dp tall in landscape** — and the
/// card's action button sat below the fold. The ticket could not be advanced
/// at all. The card is one column of chips, ticket number, every line, the
/// note and the total, with the button last, so a ticket with a few lines is
/// simply taller than the lane.
///
/// This repo has paid for this exact lesson once already: the August pairing
/// test asserted the button EXISTED and passed throughout, while it was off
/// screen and pairing was impossible from the product. So this asserts the
/// button's RECT is inside the viewport, not that a finder matched.
void _theActionIsAlwaysOnScreen() {
  testWidgets('the action button is reachable on a short kitchen screen', (
    tester,
  ) async {
    final PosStore store = SqlitePosStore.inMemory();
    addTearDown(store.close);
    const PosDeviceIdentity identity = PosDeviceIdentity(
      deviceId: 'kds-cuisine',
      branchId: 'branch-1',
      role: PosDeviceRole.kds,
      label: 'Cuisine',
    );
    store.writeIdentity(identity);
    final PosEngine engine = PosEngine(store: store, identity: identity);

    const MenuSnapshot draft = MenuSnapshot(
      version: 1,
      branchId: 'branch-1',
      declaredProductCount: 1,
      checksum: '',
      products: <SnapshotProduct>[
        SnapshotProduct(
          productId: 'p-long',
          nameFr: 'Pepper soup de bœuf TIMMA',
          nameEn: 'TIMMA beef pepper soup',
          basePrice: 3500,
          type: 'dish',
          available: true,
        ),
      ],
    );
    final MenuSnapshot menu = MenuSnapshot(
      version: draft.version,
      branchId: draft.branchId,
      declaredProductCount: draft.declaredProductCount,
      products: draft.products,
      checksum: draft.computeChecksum(),
    );
    store.stageSnapshot(menu, DateTime.utc(2026, 11, 22));
    store.activateSnapshot(menu.version, DateTime.utc(2026, 11, 22));

    // A ticket with enough on it to outgrow a short lane, and a note too.
    engine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-long', quantity: 2),
        PosCartLine(productId: 'p-long', quantity: 1),
        PosCartLine(productId: 'p-long', quantity: 3),
      ],
      note: 'Sans piment, bien chaud, à emporter tout de suite',
    );

    // The Samsung SM-G975F in landscape: 2280 x 1080 px at 420 dpi.
    tester.view.physicalSize = const Size(2280, 1080);
    tester.view.devicePixelRatio = 420 / 160;
    addTearDown(tester.view.reset);

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

    // ⚠ Scoped to the CARD. A bare `find.byType(FilledButton)` matches the
    // header's *Couper l'alarme* first, which is always on screen — so the
    // assertion passed with the bug still in place. Caught by deleting the fix
    // and watching the test stay green, which is the only way to know.
    final Finder action = find.descendant(
      of: find.byType(KdsTicketCard),
      matching: find.byType(FilledButton),
    );
    expect(action, findsWidgets, reason: 'the ticket must offer an action');

    // ⚠⚠ **On screen WITHOUT scrolling.** Owner, 2026-11-24, on the real
    // board: *"be sure the user can always click on all buttons — currently
    // Encaisser is not reachable on kitchen"*. For one turn this test allowed
    // the cook to scroll to it; that was the wrong trade, and this is the
    // assertion that holds the right one. The card adapts instead — on a
    // short board it leads with the ticket code and the dishes and shrinks
    // its own chrome, so the action never leaves the viewport.
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect rect = tester.getRect(action.first);
    expect(
      rect.bottom,
      lessThanOrEqualTo(screen.height + 0.5),
      reason:
          'the action ran ${rect.bottom - screen.height} dp past the '
          'bottom of a ${screen.height} dp screen even after scrolling to it '
          '— a cook cannot press it',
    );
    expect(rect.top, greaterThanOrEqualTo(-0.5));

    // And it really is pressable: a rect inside the viewport that nothing can
    // hit is the same defect wearing a different hat.
    await tester.tap(action.first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
