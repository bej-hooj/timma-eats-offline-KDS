import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_link/pos_link.dart';
import 'package:pos_link_flutter/pos_link_flutter.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/domain/kds_alarm.dart';
import 'package:timma_kds/kds/domain/kds_lanes.dart';
import 'package:timma_kds/kds/link/kds_link.dart';
import 'package:timma_kds/kds/pairing/pairing_controller.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

/// **An order placed on the kiosk arrives in the kitchen, and is heard.**
///
/// This is the question the whole product turns on, and it had no test —
/// because it had no implementation. The board paired, wrote a credential, and
/// never opened a socket; the alarm's rules were written, tested and connected
/// to nothing. Both gaps looked identical from a green suite.
///
/// So: a real [LanHubServer] on loopback, the board's real pairing controller,
/// its real link controller, its real board controller, and a recording
/// speaker in place of the tablet's. Nothing here is a mock except the platform
/// keystore, which cannot exist on a host.
/// Shorter than every periodic timer in the board (`refreshEvery` 5 s) and the
/// link (`pumpEvery` 3 s). An assertion that outlives those is not proving the
/// wiring — it is proving that a timer eventually fired.
const Duration _beforeTheTimers = Duration(seconds: 2);

void main() {
  late PosStore hubStore;
  late PosStore boardStore;
  late PosEngine hubEngine;
  late LanHubServer server;
  late PairingRegistry registry;
  late _MemoryStore keystore;
  late RecordingAlarmSink speaker;
  late HubEndpoint endpoint;

  const String branchId = '10000000-0000-4000-8000-000000000001';
  final BranchCollectionSecret branchSecret = BranchCollectionSecret.fromBytes(
    List<int>.generate(32, (int i) => (i * 7 + 3) % 256),
  );

  const PosDeviceIdentity hubIdentity = PosDeviceIdentity(
    deviceId: 'kiosk-door',
    branchId: branchId,
    role: PosDeviceRole.kiosk,
    label: 'Borne entrée',
  );

  MenuSnapshot menu() {
    const MenuSnapshot draft = MenuSnapshot(
      version: 1,
      branchId: branchId,
      declaredProductCount: 1,
      products: <SnapshotProduct>[
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

  setUp(() async {
    hubStore = SqlitePosStore.inMemory();
    hubStore.writeIdentity(hubIdentity);
    final MenuSnapshot m = menu();
    hubStore.stageSnapshot(m, DateTime.utc(2026, 8, 18));
    hubStore.activateSnapshot(m.version, DateTime.utc(2026, 8, 18));
    hubEngine = PosEngine(store: hubStore, identity: hubIdentity);

    boardStore = SqlitePosStore.inMemory();
    keystore = _MemoryStore();
    speaker = RecordingAlarmSink();

    registry = PairingRegistry(collectionSecret: branchSecret);
    server = LanHubServer(engine: hubEngine, pairing: registry);
    endpoint = await server.start(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
  });

  tearDown(() async {
    await server.close();
    hubStore.close();
    boardStore.close();
  });

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
        kdsAlarmSinkProvider.overrideWithValue(speaker),
        kdsIntentPublisherProvider.overrideWith(
          (Ref ref) =>
              () => ref.read(kdsLinkProvider.notifier).pump(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  HubAdvertisement advertisement() => HubAdvertisement(
    endpoint: endpoint,
    hubDeviceId: hubIdentity.deviceId,
    hubLabel: hubIdentity.label,
    branchId: branchId,
  );

  Future<ProviderContainer> paired() async {
    final ProviderContainer c = container();
    final PairingCode code = await registry.begin();
    c.read(kdsPairingProvider.notifier).select(advertisement());
    await c.read(kdsPairingProvider.notifier).join(code.value);
    expect(c.read(kdsPairingProvider).paired, isTrue);
    return c;
  }

  /// Polls until [predicate] holds. The socket is real, so "it arrived" is an
  /// event in time rather than a return value — and a fixed sleep would either
  /// be flaky or slow, on a suite that runs on every push.
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

  test('pairing remembers WHERE the kiosk is, not just who it is', () async {
    final ProviderContainer c = await paired();
    addTearDown(() => c.read(kdsLinkProvider.notifier).stop());

    final HubEndpoint? remembered = KdsHubAddress.read(boardStore);
    expect(
      remembered,
      isNotNull,
      reason:
          'a board that forgets the address comes back from a restart '
          'fully provisioned and unable to connect to anything',
    );
    expect(remembered!.host, endpoint.host);
    expect(remembered.port, endpoint.port);
  });

  test('a board that restarts reconnects with no re-pairing', () async {
    final ProviderContainer first = await paired();
    await until(() => first.read(kdsLinkProvider).connected);
    // The tablet is switched off: the container goes, the database stays.
    first.dispose();

    // A cold start: nothing but the store on disk and the keystore.
    final ProviderContainer second = container();
    addTearDown(() => second.read(kdsLinkProvider.notifier).stop());
    expect(second.read(kdsIdentityProvider), isNotNull);
    await second.read(kdsLinkProvider.notifier).start();

    await until(
      () => second.read(kdsLinkProvider).connected,
      reason: 'the board did not find the kiosk again after a restart',
    );
  });

  test('an order rung on the kiosk reaches the kitchen — and rings', () async {
    final ProviderContainer c = await paired();
    addTearDown(() => c.read(kdsLinkProvider.notifier).stop());
    await until(() => c.read(kdsLinkProvider).connected);

    // The board is watched, exactly as a mounted tablet watches it.
    c.read(kdsBoardProvider);
    expect(speaker.rung, isEmpty, reason: 'an empty board is silent');

    // A customer buys a chicken at the kiosk.
    final PlacedOrder placed = hubEngine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 1),
      ],
    );
    server.publishBoard();

    await until(
      () => c.read(kdsBoardProvider).lane(KdsLane.counter).isNotEmpty,
      reason: 'the order never arrived on the board',
      // ⚠ **Deliberately shorter than `KdsBoardController.refreshEvery`.** The
      // board also re-reads on a 5-second timer, so a 5-second wait here would
      // pass whether or not the snapshot ever pushed anything — the exact
      // shape of the vacuous guard test this project has already shipped once.
      within: _beforeTheTimers,
    );

    final PosOrder arrived = c
        .read(kdsBoardProvider)
        .lane(KdsLane.counter)
        .single;
    expect(arrived.clientId, placed.order.clientId);
    expect(arrived.total, 4500);
    expect(
      speaker.rung,
      // The ticket lands in *À encaisser* — unpaid — so the register is
      // `counter`, which since ECOSYSTEM v1.25 has its own tone. Asserting
      // the lane's own register rather than "something rang" is what would
      // catch the two lanes being merged back into one sound.
      contains(KdsAlarmRegister.counter),
      reason:
          'THE ALARM. A ticket that lands in silence is a ticket the '
          'kitchen finds when the customer asks for it',
    );
  });

  test('what the cook taps gets back to the kiosk', () async {
    final ProviderContainer c = await paired();
    addTearDown(() => c.read(kdsLinkProvider.notifier).stop());
    await until(() => c.read(kdsLinkProvider).connected);
    c.read(kdsBoardProvider);

    final PlacedOrder placed = hubEngine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 1),
      ],
    );
    final String id = placed.order.clientId;
    server.publishBoard();
    await until(
      () => c.read(kdsBoardProvider).lane(KdsLane.counter).isNotEmpty,
      within: _beforeTheTimers,
    );

    // Cash at the counter, then accepted in the kitchen.
    c.read(kdsBoardProvider.notifier).settleCash(id);
    await until(
      () => hubStore.findOrder(id)!.paymentStatus == PosPaymentStatus.paid,
      reason: 'the kiosk never learned the cash was taken',
      // Under `KdsLinkController.pumpEvery`, so this proves the tap pushed and
      // not that a background pump eventually caught up.
      within: _beforeTheTimers,
    );

    c.read(kdsBoardProvider.notifier).advance(hubStore.findOrder(id)!);
    await until(
      () => hubStore.findOrder(id)!.status == PosOrderStatus.accepted,
      reason:
          'a transition tapped in the kitchen never reached the kiosk — '
          'the outbox was written and nothing drained it',
      within: _beforeTheTimers,
    );
  });

  test('muting the run does not swallow the next order', () async {
    final ProviderContainer c = await paired();
    addTearDown(() => c.read(kdsLinkProvider.notifier).stop());
    await until(() => c.read(kdsLinkProvider).connected);
    c.read(kdsBoardProvider);

    hubEngine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 1),
      ],
    );
    server.publishBoard();
    await until(
      () => c.read(kdsBoardProvider).lane(KdsLane.counter).isNotEmpty,
      within: _beforeTheTimers,
    );
    expect(speaker.rung, hasLength(1));

    c.read(kdsBoardProvider.notifier).muteAlarm();
    expect(speaker.silenced, 1, reason: 'the sound stops mid-file, not after');
    expect(c.read(kdsBoardProvider).alarmMuted, isTrue);
    expect(c.read(kdsBoardProvider).alarming, isFalse);

    // A second customer, while the first ticket is still unclaimed.
    hubEngine.placeKioskOrder(
      lines: const <PosCartLine>[
        PosCartLine(productId: 'p-poulet', quantity: 2),
      ],
    );
    server.publishBoard();
    await until(
      () => c.read(kdsBoardProvider).lane(KdsLane.counter).length == 2,
      within: _beforeTheTimers,
    );
    expect(
      speaker.rung,
      hasLength(2),
      reason: 'muting one nag must never mute the NEXT arrival',
    );
    expect(c.read(kdsBoardProvider).alarmMuted, isFalse);
  });
}

/// The platform keystore, in memory.
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
