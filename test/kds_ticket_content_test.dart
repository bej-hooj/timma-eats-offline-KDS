import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/domain/kds_lanes.dart';
import 'package:timma_kds/kds/kds_app.dart';
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
    expect(find.text('Plantain · Sauce piquante'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the lanes are the take-away spine, not six fixed columns', (
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
