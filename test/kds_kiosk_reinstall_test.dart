import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_link/pos_link.dart';
import 'package:pos_link_flutter/pos_link_flutter.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/domain/kds_lanes.dart';
import 'package:timma_kds/kds/link/kds_link.dart';
import 'package:timma_kds/kds/pairing/pairing_controller.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

/// **A kiosk that was reinstalled can be paired to again.**
///
/// This is the owner's own failure, reported from the two real tablets: the
/// board answered *Impossible d'enregistrer la clé de sécurité sur cette
/// tablette* and the kiosk stayed on *0 cuisines connectées*. A reinstalled
/// kiosk mints a **new branch collection secret**; the board already held the
/// old one, and `writeOnce` — correctly, by its own rule — refused to replace
/// it. On iOS the keychain survives an app uninstall, so reinstalling the board
/// did not clear it either. Two devices in one kitchen, and no sequence of taps
/// available on either of them that would make them work together again.
///
/// `adopt()` is the recovery ceremony the vault's documentation has required
/// since K3-SEC. It shipped with unit tests of its own, and with **no test of
/// the failure it was written for** — the end-to-end one was attempted and
/// deleted rather than left red. That is this file: the real hub, the real
/// pairing controller, the real vault, over a real socket. Only the platform
/// keystore is faked, because a keychain cannot exist on a host.
///
/// The security half matters as much as the recovery half. `adopt()` removed
/// the write-once floor, so the tests below also pin what must remain
/// impossible: a **wrong** code cannot rotate a board's secret.
void main() {
  const String branchId = '10000000-0000-4000-8000-000000000001';

  /// The same device id across the reinstall, as on the hardware: the borne's
  /// id comes from a `--dart-define`, so reinstalling the app does not change
  /// who the kiosk says it is — only the secret it mints. A test that quietly
  /// changed the id too would prove a different, easier bug.
  const PosDeviceIdentity kioskIdentity = PosDeviceIdentity(
    deviceId: 'dev-kiosk-samsung-01',
    branchId: branchId,
    role: PosDeviceRole.kiosk,
    label: 'Borne entrée',
  );

  final BranchCollectionSecret secretBefore = BranchCollectionSecret.fromBytes(
    List<int>.generate(32, (int i) => (i * 13 + 7) % 256),
  );
  final BranchCollectionSecret secretAfter = BranchCollectionSecret.fromBytes(
    List<int>.generate(32, (int i) => (i * 29 + 11) % 256),
  );

  late PosStore boardStore;
  late _MemoryKeystore keystore;

  setUp(() {
    // The board's own storage, which outlives every kiosk in this file — that
    // is the whole point. On the hardware neither of these is cleared by
    // reinstalling the kiosk, and on iOS not by reinstalling the board either.
    boardStore = SqlitePosStore.inMemory();
    keystore = _MemoryKeystore();
  });

  tearDown(() => boardStore.close());

  /// A kiosk, installed. Calling it twice with different secrets is exactly
  /// what "the borne was reinstalled" means to the board.
  Future<_Kiosk> installKiosk(BranchCollectionSecret secret) async {
    final PosStore store = SqlitePosStore.inMemory();
    store.writeIdentity(kioskIdentity);
    final MenuSnapshot menu = _menu(branchId);
    store.stageSnapshot(menu, DateTime.utc(2026, 8, 20));
    store.activateSnapshot(menu.version, DateTime.utc(2026, 8, 20));

    final PosEngine engine = PosEngine(store: store, identity: kioskIdentity);
    final PairingRegistry registry = PairingRegistry(collectionSecret: secret);
    final LanHubServer server = LanHubServer(engine: engine, pairing: registry);
    final HubEndpoint endpoint = await server.start(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    final _Kiosk kiosk = _Kiosk(
      store: store,
      engine: engine,
      registry: registry,
      server: server,
      endpoint: endpoint,
      identity: kioskIdentity,
      branchId: branchId,
    );
    addTearDown(kiosk.uninstall);
    return kiosk;
  }

  ProviderContainer board() {
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
        kdsIntentPublisherProvider.overrideWith(
          (Ref ref) =>
              () => ref.read(kdsLinkProvider.notifier).pump(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Every socket error the board's link leaked to the zone. Asserted on, not
  /// ignored: see [pair].
  final List<Object> leaked = <Object>[];

  Future<void> pair(
    ProviderContainer c,
    _Kiosk kiosk, {
    String? withCode,
  }) async {
    final PairingCode code = await kiosk.registry.begin();
    c.read(kdsPairingProvider.notifier).select(kiosk.advertisement);

    // ⚠ **`pos_link` leaks a failed connect as an unobserved async error**, and
    // an unobserved async error fails a Dart test outright. That is what killed
    // the first attempt at this file — the report was "the FIRST pairing
    // failed", when in truth the pairing had succeeded and the *test* had died
    // on a socket retrying a kiosk this test had deliberately uninstalled.
    //
    // `join()` starts the link, and its periodic pump inherits this zone, so
    // guarding here also catches the retries that follow. The errors are
    // collected rather than dropped: swallowing them wholesale would hide a
    // real failure in the very path being proved.
    //
    // The leak itself is a `pos_link` defect (`LanSocketTransport._open`,
    // already recorded for `LanPairingClient` in
    // `docs/board-link-and-alarm-2026-08-18.md`). Fixing it means moving the
    // pinned commit in both tablet repos, which must not happen between now and
    // the hardware proof of `dc0a257` — the build already installed on Bocav.
    await runZonedGuarded(
      () => c.read(kdsPairingProvider.notifier).join(withCode ?? code.value),
      (Object error, StackTrace _) => leaked.add(error),
    );
  }

  /// The only leak this file tolerates is a socket that could not be opened.
  ///
  /// Matched on the text rather than the type because `WebSocketChannelException`
  /// belongs to a transitive package, and a test should not pull a dependency
  /// into the pubspec to name an error it is only allowed to ignore.
  void expectOnlySocketNoise() {
    for (final Object error in leaked) {
      expect(
        '$error',
        anyOf(
          contains('WebSocketChannelException'),
          contains('SocketException'),
          contains('is closed'),
        ),
        reason: 'an unexpected error escaped the board: $error',
      );
    }
    leaked.clear();
  }

  /// Polls until [predicate] holds: the socket is real, so arrival is an event
  /// in time and a fixed sleep would be either flaky or slow.
  Future<void> until(
    bool Function() predicate, {
    String reason = 'condition never held',
    Duration within = const Duration(seconds: 5),
  }) async {
    final DateTime deadline = DateTime.now().add(within);
    while (DateTime.now().isBefore(deadline)) {
      if (predicate()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail(reason);
  }

  test('the board pairs again after the kiosk was reinstalled', () async {
    final _Kiosk before = await installKiosk(secretBefore);
    final ProviderContainer c = board();

    await pair(c, before);
    expect(
      c.read(kdsPairingProvider).paired,
      isTrue,
      reason:
          'the first pairing must succeed, or nothing below is a test '
          'of anything — error was ${c.read(kdsPairingProvider).error}',
    );
    expect(
      (await BranchCollectionSecretVault(
        keystore,
      ).read(branchId: branchId))!.matches(secretBefore),
      isTrue,
    );

    // ── The borne is reinstalled. ──────────────────────────────────────────
    // The board drops its socket first, as it does on the hardware: the kiosk's
    // refusal runs `stop()` and `requirePairing()` in that order. Doing it here
    // keeps this test about the secret, not about how the refusal is noticed —
    // that path has its own gap, recorded in the continuation prompt.
    await c.read(kdsLinkProvider.notifier).stop();
    c.read(kdsIdentityProvider.notifier).requirePairing();
    await before.uninstall();

    final _Kiosk after = await installKiosk(secretAfter);
    await pair(c, after);

    // ⚠ **The regression.** This was `KdsPairingError.storeFailed`, rendered as
    // *Impossible d'enregistrer la clé de sécurité sur cette tablette* — the
    // board blaming its own keystore for a secret the kiosk had legitimately
    // replaced, with no way forward from either device.
    expect(
      c.read(kdsPairingProvider).error,
      isNull,
      reason:
          'a supervised pairing is the ceremony that may rotate the '
          'secret; refusing it strands the kitchen for ever',
    );
    expect(c.read(kdsPairingProvider).paired, isTrue);

    final BranchCollectionSecret? held = await BranchCollectionSecretVault(
      keystore,
    ).read(branchId: branchId);
    expect(held, isNotNull);
    expect(
      held!.matches(secretAfter),
      isTrue,
      reason: 'the board must now hold the secret THIS kiosk signs with',
    );
    expect(
      held.matches(secretBefore),
      isFalse,
      reason:
          'the old secret is gone, not kept alongside — a board that '
          'accepted both would verify slips from a kiosk that no longer exists',
    );
    expectOnlySocketNoise();
  });

  test('and a slip from the reinstalled kiosk collects food', () async {
    // The end a customer stands at. Pairing exists so this holds with the
    // internet down, which is the only reason any of it is on the device.
    final _Kiosk before = await installKiosk(secretBefore);
    final ProviderContainer c = board();
    await pair(c, before);
    await c.read(kdsLinkProvider.notifier).stop();
    c.read(kdsIdentityProvider.notifier).requirePairing();
    await before.uninstall();

    final _Kiosk after = await installKiosk(secretAfter);
    await pair(c, after);

    final PosOrder order = _order(branchId);
    final CollectionCode printed = CollectionCode.forOrder(
      order,
      secret: secretAfter,
    );
    final BranchCollectionSecret onBoard = (await BranchCollectionSecretVault(
      keystore,
    ).read(branchId: branchId))!;

    expect(
      printed.verifies(secret: onBoard, branchId: branchId),
      isTrue,
      reason:
          'a slip printed by the reinstalled borne must collect food at '
          'this kitchen — that is what the secret is for',
    );
    expect(
      CollectionCode.forOrder(
        order,
        secret: secretBefore,
      ).verifies(secret: onBoard, branchId: branchId),
      isFalse,
      reason: 'a slip signed by the kiosk that no longer exists must not',
    );
    expectOnlySocketNoise();
  });

  test('a wrong code cannot rotate the secret', () async {
    // ⚠ The security half of `adopt()`. It removed the write-once floor, so the
    // handshake is now the ONLY thing standing between a board's signing key
    // and whoever is on the wifi. A pairing that fails must leave the stored
    // secret exactly where it was.
    final _Kiosk before = await installKiosk(secretBefore);
    final ProviderContainer c = board();
    await pair(c, before);
    await c.read(kdsLinkProvider.notifier).stop();
    c.read(kdsIdentityProvider.notifier).requirePairing();
    await before.uninstall();

    final _Kiosk rogue = await installKiosk(secretAfter);
    final PairingCode real = await rogue.registry.begin();
    final String wrong = real.value == '000000' ? '111111' : '000000';
    c.read(kdsPairingProvider.notifier).select(rogue.advertisement);
    await c.read(kdsPairingProvider.notifier).join(wrong);

    expect(c.read(kdsPairingProvider).paired, isFalse);
    expect(c.read(kdsPairingProvider).error, KdsPairingError.badCode);
    expect(
      (await BranchCollectionSecretVault(
        keystore,
      ).read(branchId: branchId))!.matches(secretBefore),
      isTrue,
      reason: 'six digits nobody read off the kiosk are not a ceremony',
    );
    expectOnlySocketNoise();
  });

  test('re-pairing moves the socket, not just the database', () async {
    // ⚠ The board does NOT always get to stop its link first. A kiosk that is
    // simply gone is noticed on the link's own 3-second pump, and a manager
    // walking back from the borne with six digits is faster than that — so
    // pairing can, and on the hardware does, run while the old transport is
    // still retrying the dead address. `start()` is idempotent and returns
    // early when a transport exists, so without dropping the old one first the
    // board would pair perfectly, write the new address, and go on talking to
    // a kiosk that no longer exists until somebody restarted the tablet.
    final _Kiosk before = await installKiosk(secretBefore);
    final ProviderContainer c = board();
    await pair(c, before);
    await until(
      () => c.read(kdsLinkProvider).connected,
      reason: 'the board never connected to the first kiosk',
    );

    await before.uninstall();
    final _Kiosk after = await installKiosk(secretAfter);
    // No `stop()`, no `requirePairing()`: this is the impatient manager.
    await pair(c, after);
    expect(c.read(kdsPairingProvider).paired, isTrue);

    c.read(kdsBoardProvider);
    after.engine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 1),
      ],
    );
    after.server.publishBoard();

    await until(
      () => c.read(kdsBoardProvider).lane(KdsLane.counter).isNotEmpty,
      reason:
          'an order rung on the reinstalled kiosk never reached the '
          'board — the socket was still pointed at the old one',
      // Shorter than the board's own 5-second refresh, so this cannot pass on
      // a timer having fired rather than on a snapshot having arrived.
      within: const Duration(seconds: 3),
    );
    addTearDown(() => c.read(kdsLinkProvider.notifier).stop());
    expectOnlySocketNoise();
  });
}

/// One installation of the borne: its store, its engine, its secret, its socket.
class _Kiosk {
  _Kiosk({
    required this.store,
    required this.engine,
    required this.registry,
    required this.server,
    required this.endpoint,
    required this.identity,
    required this.branchId,
  });

  final PosStore store;
  final PosEngine engine;
  final PairingRegistry registry;
  final LanHubServer server;
  final HubEndpoint endpoint;
  final PosDeviceIdentity identity;
  final String branchId;
  bool _gone = false;

  HubAdvertisement get advertisement => HubAdvertisement(
    endpoint: endpoint,
    hubDeviceId: identity.deviceId,
    hubLabel: identity.label,
    branchId: branchId,
  );

  Future<void> uninstall() async {
    if (_gone) {
      return;
    }
    _gone = true;
    await server.close();
    store.close();
  }
}

MenuSnapshot _menu(String branchId) {
  final MenuSnapshot draft = MenuSnapshot(
    version: 1,
    branchId: branchId,
    declaredProductCount: 1,
    products: const <SnapshotProduct>[
      SnapshotProduct(
        productId: 'p-poulet',
        nameFr: 'Poulet DG',
        nameEn: 'Chicken DG',
        basePrice: 4500,
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

PosOrder _order(String branchId) => PosOrder(
  clientId: 'c-1',
  branchId: branchId,
  origin: PosOrderOrigin.local,
  source: PosOrderSource.kiosk,
  mode: PosOrderMode.pickup,
  status: PosOrderStatus.pendingPayment,
  paymentStatus: PosPaymentStatus.unpaid,
  paymentMethod: PosPaymentMethod.payAtCounter,
  deviceSeq: 1,
  subtotal: 4500,
  discount: 0,
  deliveryFee: 0,
  total: 4500,
  ticketNumber: 42,
  placedAtDevice: DateTime.utc(2026, 8, 20, 18),
  statusChangedAt: DateTime.utc(2026, 8, 20, 18),
);

/// The platform keystore, in memory. Survives every kiosk in a test, exactly as
/// the iOS keychain survives an uninstall.
class _MemoryKeystore implements SecureValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
