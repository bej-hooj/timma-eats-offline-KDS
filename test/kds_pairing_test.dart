import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_link/pos_link.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import 'package:timma_kds/kds/kds_root.dart';
import 'package:timma_kds/kds/pairing/pairing_controller.dart';
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
  _codeStepFitsTests();
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

  testWidgets('typing the six digits enables Apparier', (tester) async {
    // ⚠ The bug this exists for: the button's enabled state read `_code.text`
    // while the screen only rebuilt on PAIRING state changes, so typing all six
    // digits left *Apparier* disabled and pairing was impossible from the
    // product. Reported from the device, not caught here — so it is caught here
    // now.
    await pump(tester);

    // Reach the code step through the manual address path, without a network:
    // selecting a hub is what reveals the keypad.
    final KdsPairingController controller = ProviderScope.containerOf(
      tester.element(find.byType(KdsPairingScreen)),
    ).read(kdsPairingProvider.notifier);
    controller.select(
      HubAdvertisement(
        endpoint: const HubEndpoint(host: '192.168.1.50', port: 8801),
        hubDeviceId: 'kiosk-door',
        hubLabel: 'Borne entrée',
        branchId: 'branch-1',
      ),
    );
    await tester.pumpAndSettle();

    // ⚠ The code is the SECOND procedure since 2026-11-22 and is revealed, not
    // shown: one tap is the first. Both paths on screen at once ran the button
    // 53 px off a 390 dp board, which is what the landscape test below guards.
    await tester.tap(find.text('Ou saisissez le code affiché sur la borne'));
    await tester.pumpAndSettle();

    Finder joinButton() => find.widgetWithText(FilledButton, 'Apparier');
    expect(
      tester.widget<FilledButton>(joinButton()).onPressed,
      isNull,
      reason: 'nothing typed yet',
    );

    await tester.enterText(find.byType(TextField).first, '758388');
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(joinButton()).onPressed,
      isNotNull,
      reason: 'six digits typed — the only remaining step must be pressable',
    );

    // Five digits is not a code, and must not be offered as one.
    await tester.enterText(find.byType(TextField).first, '75838');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(joinButton()).onPressed, isNull);
  });

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

/// The code step must FIT the board it ships on.
///
/// ⚠ Reported from the device: at 844 x 390 — a phone-sized board in landscape,
/// which is exactly what the cuisine runs on — the title, subtitle, kiosk card,
/// prompt, the big code field and the button did not fit, and the page would
/// not scroll to the button either. *Apparier* could not be reached at all, so
/// pairing was impossible from the product. A widget test that only asserts the
/// button EXISTS would have passed the whole time; this one asserts it is on
/// screen.
void _codeStepFitsTests() {
  testWidgets('Apparier is reachable on a landscape board, in French', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final PosStore store = SqlitePosStore.inMemory();
    addTearDown(store.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [kdsStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: KdsPairingScreen(),
        ),
      ),
    );
    await tester.pump();

    // Pick a kiosk, which is what reveals the code step.
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(KdsPairingScreen)),
    );
    container
        .read(kdsPairingProvider.notifier)
        .select(
          const HubAdvertisement(
            endpoint: HubEndpoint(host: '192.168.1.245', port: 8801),
            hubDeviceId: 'kiosk-door',
            hubLabel: 'Borne (debug)',
            branchId: '10000000-0000-4000-8000-000000000001',
          ),
        );
    await tester.pump();

    // ⚠ The ONE-TAP action is what a cook meets first now, so it is what must
    // be on screen first. Asserted before the code path is even revealed.
    final Finder tap = find.widgetWithText(FilledButton, 'Apparier en un geste');
    expect(tap, findsOneWidget);
    final Size screenSize =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      tester.getRect(tap).bottom,
      lessThanOrEqualTo(screenSize.height),
      reason: 'the one-tap action must be on screen without scrolling',
    );

    // Then the fallback, revealed.
    await tester.tap(find.text('Ou saisissez le code affiché sur la borne'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '182531');
    await tester.pump();

    final Finder join = find.widgetWithText(FilledButton, 'Apparier');
    expect(join, findsOneWidget);

    // On screen, not merely in the tree.
    final Rect box = tester.getRect(join);
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      box.bottom,
      lessThanOrEqualTo(screen.height),
      reason:
          'the pairing action ran off the bottom of the board and the page '
          'would not scroll to it — pairing was impossible from the product',
    );
    expect(tester.takeException(), isNull);
  });
}
