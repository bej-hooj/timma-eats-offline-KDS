import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_link_flutter/pos_link_flutter.dart';
import 'package:timma_kds/kds/access/kds_view.dart';
import 'package:timma_kds/kds/access/kds_view_controller.dart';
import 'package:timma_kds/kds/access/kds_view_picker.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/kds_root.dart';
import 'package:timma_kds/kds/pairing/pairing_controller.dart';
import 'package:timma_kds/kds/presentation/board_screen.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

/// **A board the kiosk does not know must ask to be paired, not show lanes.**
///
/// Reported from a real tablet, angrily and rightly. The cuisine sat on the
/// board — six empty lanes — while the kiosk two metres away had never heard of
/// it, and there was no way back to the pairing screen from anywhere in the
/// product. An identity in `kds.db` was being treated as proof of pairing, and
/// on iOS that database survives a reinstall, so the state was unescapable
/// short of wiping the device.
void main() {
  late PosStore boardStore;
  late _MemoryStore keystore;

  const String branchId = '10000000-0000-4000-8000-000000000001';

  const PosDeviceIdentity staleIdentity = PosDeviceIdentity(
    deviceId: 'kds-from-a-previous-life',
    branchId: branchId,
    role: PosDeviceRole.kds,
    label: 'Cuisine',
  );

  setUp(() {
    boardStore = SqlitePosStore.inMemory();
    keystore = _MemoryStore();
  });

  tearDown(() => boardStore.close());

  ProviderContainer container() {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        kdsStoreProvider.overrideWithValue(boardStore),
        kdsCredentialVaultProvider.overrideWithValue(
          KdsCredentialVault(keystore),
        ),
        kdsSecretVaultProvider.overrideWithValue(
          BranchCollectionSecretVault(keystore),
        ),
        kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a stale identity alone still counts as paired', () {
    boardStore.writeIdentity(staleIdentity);
    expect(
      container().read(kdsIdentityProvider),
      isNotNull,
      reason:
          'an ordinary restart must not throw a working board off its '
          'kiosk — only the kiosk itself gets to say no',
    );
  });

  test('a kiosk that refuses this board sends it back to pairing', () {
    boardStore.writeIdentity(staleIdentity);
    final ProviderContainer c = container();
    expect(c.read(kdsIdentityProvider), isNotNull);

    // What the transport reports when the hub answers "I have never heard of
    // you" — a reinstalled kiosk to a board whose database survived.
    c.read(kdsIdentityProvider.notifier).requirePairing();

    expect(
      c.read(kdsIdentityProvider),
      isNull,
      reason: 'the board is not paired, whatever its database says',
    );
    expect(
      KdsPairingGate.isRequired(boardStore),
      isTrue,
      reason:
          'and it must still be true after a restart — otherwise the '
          'tablet comes back to the same dead end',
    );
    // The restart itself.
    expect(container().read(kdsIdentityProvider), isNull);
  });

  testWidgets('that board shows the pairing screen, not empty lanes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    boardStore.writeIdentity(staleIdentity);
    KdsPairingGate.require(boardStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsStoreProvider.overrideWithValue(boardStore),
          kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
        ],
        child: const KdsRoot(),
      ),
    );
    await tester.pump();

    expect(find.text('Apparier cette cuisine'), findsOneWidget);
    expect(
      find.byType(KdsBoardScreen),
      findsNothing,
      reason: 'lanes nothing will ever fill are worse than an honest ask',
    );
  });

  testWidgets('a manager can always get back to pairing from the board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    boardStore.writeIdentity(staleIdentity);
    // S5: a paired board first asks which view; this one already chose.
    boardStore.writeMeta(KdsViewController.metaKey, KdsView.kitchen);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsStoreProvider.overrideWithValue(boardStore),
          kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
        ],
        child: const KdsRoot(),
      ),
    );
    await tester.pump();
    expect(find.byType(KdsBoardScreen), findsOneWidget);

    // The kiosk's own gesture, on the board's logo. Found by the GESTURE, not
    // by the artwork: the logo collapses to nothing when the asset will not
    // decode, and the way out must survive that.
    await tester.longPress(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    expect(find.text('Apparier une autre borne'), findsOneWidget);

    await tester.tap(find.text('Apparier à nouveau'));
    await tester.pumpAndSettle();

    expect(
      find.text('Apparier cette cuisine'),
      findsOneWidget,
      reason:
          'the board must never be a dead end — moving a tablet to another '
          'kiosk cannot require reinstalling it',
    );
  });

  testWidgets('a paired board with no view chosen asks « Cuisine » or '
      '« Caisse paiement » — and « Changer de vue » comes back here', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    boardStore.writeIdentity(staleIdentity);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsStoreProvider.overrideWithValue(boardStore),
          kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
        ],
        child: const KdsRoot(),
      ),
    );
    await tester.pump();
    expect(find.byType(KdsViewPicker), findsOneWidget);
    expect(find.byType(KdsBoardScreen), findsNothing);

    await tester.tap(find.byKey(const Key('kds-view-kitchen')));
    await tester.pumpAndSettle();
    expect(find.byType(KdsBoardScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('kds-switch-view')));
    await tester.pumpAndSettle();
    expect(find.byType(KdsViewPicker), findsOneWidget);
  });
}

class _MemoryStore implements SecureValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
