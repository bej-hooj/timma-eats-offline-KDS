import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/kds/presentation/bootstrap_screen.dart';

/// A fresh install must render, not crash.
///
/// The entrypoint used to read `store.readIdentity()!`. On a tablet straight out
/// of the box — or one whose app data was cleared — that threw before `runApp`,
/// so a cook got a blank screen mid-service with nothing to report to anyone.
void main() {
  test('a fresh store has no identity — the value the old `!` crashed on', () {
    final PosStore store = SqlitePosStore.inMemory();
    addTearDown(store.close);

    expect(
      store.readIdentity(),
      isNull,
      reason: 'this is the exact state a new tablet boots in, so the entrypoint '
          'must branch on it rather than assert it away',
    );
  });

  testWidgets('the unpaired board explains itself, in French', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const KdsBootstrapApp(state: KdsBootstrapState.unpaired),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tablette non appariée'), findsOneWidget);
    expect(
      find.textContaining('appariée à une borne'),
      findsOneWidget,
      reason: 'it names the missing step, not an error code',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('it lays out at a real kitchen-tablet size without overflowing', (
    tester,
  ) async {
    // The four French-string defects this project has already paid for were all
    // "fits in English, overflows in French at a real width".
    for (final Size size in <Size>[
      const Size(2400, 1600),
      const Size(1920, 1200),
      const Size(1280, 800),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 2;
      await tester.pumpWidget(
        const KdsBootstrapApp(state: KdsBootstrapState.unpaired),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'at $size');
    }
    addTearDown(tester.view.reset);
  });
}
