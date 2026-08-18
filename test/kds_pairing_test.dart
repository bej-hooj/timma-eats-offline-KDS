import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/kds/kds_root.dart';
import 'package:timma_kds/kds/pairing/pairing_screen.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

/// An unpaired board must offer a way to pair, not a dead end.
///
/// This screen replaced one that only ever said "not paired" — true, and
/// useless, because nothing in the product could change it. A manager's only
/// remedy was to reinstall, which is why this suite asserts the ROUTE exists:
/// no identity means the pairing screen, an identity means the board, and the
/// switch happens without anyone restarting the app.
void main() {
  late PosStore store;

  setUp(() => store = SqlitePosStore.inMemory());
  tearDown(() => store.close());

  Widget app() => ProviderScope(
    overrides: [kdsStoreProvider.overrideWithValue(store)],
    child: const KdsRoot(),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2280, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  testWidgets('a board with no identity lands on pairing, in French', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(KdsPairingScreen), findsOneWidget);
    expect(find.text('Apparier cette cuisine'), findsOneWidget);
    expect(
      find.text('Chercher la borne'),
      findsOneWidget,
      reason: 'the remedy is on the screen, not in a reinstall',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('both ways in are visible at once, without scrolling', (
    tester,
  ) async {
    await pump(tester);

    // ⚠ The manual address used to hide behind a toggle at the bottom of a
    // scroll. On this exact screen size that put it below the fold, so a
    // manager on a router with multicast disabled — most of them — saw only a
    // search that finds nothing. Both paths are asserted PRESENT and ON SCREEN.
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final Finder finder in <Finder>[
      find.text('Chercher la borne'),
      find.text('Adresse de la borne'),
      find.text('Se connecter'),
    ]) {
      expect(finder, findsOneWidget);
      final Rect rect = tester.getRect(finder);
      expect(
        rect.bottom <= screen.height && rect.top >= 0,
        isTrue,
        reason: 'off screen without scrolling: $rect vs $screen',
      );
    }
  });

  testWidgets(
    'a board that already has an identity goes straight to the board',
    (tester) async {
      store.writeIdentity(
        const PosDeviceIdentity(
          deviceId: 'kds-1',
          branchId: 'branch-1',
          role: PosDeviceRole.kds,
          label: 'Cuisine',
        ),
      );

      await pump(tester);

      expect(
        find.byType(KdsPairingScreen),
        findsNothing,
        reason: 'a paired board never asks to be paired again',
      );
    },
  );

  testWidgets('the pairing screen fits real tablet sizes, in French', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final (Size size, double ratio) in <(Size, double)>[
      (const Size(2280, 1080), 2.625),
      (const Size(2560, 1600), 2.0),
      (const Size(1920, 1200), 2.0),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
  });
}
