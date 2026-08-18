import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_link/pos_link.dart';
import 'package:pos_link_flutter/pos_link_flutter.dart';
import 'package:timma_kds/kds/pairing/pairing_controller.dart';
import 'package:timma_kds/kds/state/kds_board.dart';

/// **The handshake, end to end, with no screens and no devices.**
///
/// This is the one path that decides whether a restaurant's two tablets can
/// work together, and until now it could only be exercised by hand on two
/// handsets — which meant every UI bug in front of it (a dead button, a hidden
/// field) blocked the proof entirely.
///
/// So the board's real controller runs against a real [LanHubServer] over a real
/// socket on loopback. Only the keystore is faked, because a platform channel
/// cannot exist on a host; everything that decides security — the key exchange,
/// the proof over the shared key, the wrapped branch secret — is the production
/// code.
void main() {
  late PosStore hubStore;
  late PosStore boardStore;
  late LanHubServer server;
  late PairingRegistry registry;
  late _MemoryStore keystore;
  late HubEndpoint endpoint;

  const String branchId = '10000000-0000-4000-8000-000000000001';
  final BranchCollectionSecret branchSecret = BranchCollectionSecret.fromBytes(
    List<int>.generate(32, (int i) => (i * 13 + 7) % 256),
  );

  const PosDeviceIdentity hubIdentity = PosDeviceIdentity(
    deviceId: 'kiosk-door',
    branchId: branchId,
    role: PosDeviceRole.kiosk,
    label: 'Borne entrée',
  );

  setUp(() async {
    hubStore = SqlitePosStore.inMemory();
    hubStore.writeIdentity(hubIdentity);
    boardStore = SqlitePosStore.inMemory();
    keystore = _MemoryStore();

    registry = PairingRegistry(collectionSecret: branchSecret);
    server = LanHubServer(
      engine: PosEngine(store: hubStore, identity: hubIdentity),
      pairing: registry,
    );
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

  test('the right code pairs, and stores all three things together', () async {
    final ProviderContainer c = container();
    final KdsPairingController board = c.read(kdsPairingProvider.notifier);
    final PairingCode code = await registry.begin();

    board.select(advertisement());
    await board.join(code.value);

    final KdsPairingState state = c.read(kdsPairingProvider);
    expect(state.paired, isTrue, reason: 'error was ${state.error}');
    expect(state.error, isNull);

    // 1. The identity, adopted from the hub that was approved.
    final PosDeviceIdentity? identity = boardStore.readIdentity();
    expect(identity, isNotNull);
    expect(identity!.branchId, branchId, reason: 'claimed by that branch');
    expect(identity.role, PosDeviceRole.kds);

    // 2. The credential, which every later frame is signed with.
    final DeviceCredential? credential = await KdsCredentialVault(
      keystore,
    ).read(identity.deviceId);
    expect(credential, isNotNull);

    // 3. The branch collection secret — the thing that lets this board verify a
    //    printed slip during an outage, which is its whole offline purpose.
    final BranchCollectionSecret? stored = await BranchCollectionSecretVault(
      keystore,
    ).read(branchId: branchId);
    expect(stored, isNotNull);
    expect(
      stored!.matches(branchSecret),
      isTrue,
      reason: 'the board holds the SAME branch secret the kiosk signs with',
    );

    // And the board is now visible to the hub as one identity, not two.
    expect(c.read(kdsIdentityProvider)?.deviceId, identity.deviceId);
  });

  test(
    'a slip signed by the kiosk verifies on the board it just paired',
    () async {
      // The end the customer sees: pairing exists so this holds with no network.
      final ProviderContainer c = container();
      final KdsPairingController board = c.read(kdsPairingProvider.notifier);
      final PairingCode code = await registry.begin();
      board.select(advertisement());
      await board.join(code.value);

      final PosOrder order = PosOrder(
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
        placedAtDevice: DateTime.utc(2026, 8, 18, 18),
        statusChangedAt: DateTime.utc(2026, 8, 18, 18),
      );

      // Minted by the kiosk's secret; verified by what the board was given.
      final CollectionCode printed = CollectionCode.forOrder(
        order,
        secret: branchSecret,
      );
      final BranchCollectionSecret? onBoard = await BranchCollectionSecretVault(
        keystore,
      ).read(branchId: branchId);

      expect(
        printed.verifies(secret: onBoard!, branchId: branchId),
        isTrue,
        reason: 'a slip from this kiosk collects food at this kitchen',
      );
    },
  );

  test('a wrong code is refused and nothing is stored', () async {
    final ProviderContainer c = container();
    final KdsPairingController board = c.read(kdsPairingProvider.notifier);
    final PairingCode code = await registry.begin();
    final String wrong = code.value == '000000' ? '111111' : '000000';

    board.select(advertisement());
    await board.join(wrong);

    final KdsPairingState state = c.read(kdsPairingProvider);
    expect(state.paired, isFalse);
    expect(state.error, isNotNull);
    expect(
      boardStore.readIdentity(),
      isNull,
      reason:
          'a refused pairing must leave no identity behind — a board with '
          'an identity and no credential looks paired and cannot work',
    );
    expect(keystore.values, isEmpty);
  });

  test('an expired code is refused', () async {
    final ProviderContainer c = container();
    final KdsPairingController board = c.read(kdsPairingProvider.notifier);
    final PairingCode code = await registry.begin();

    // A new pairing window invalidates the previous one: the registry holds a
    // single pending pairing, which is what makes a code single-use.
    await registry.begin();

    board.select(advertisement());
    await board.join(code.value);

    expect(c.read(kdsPairingProvider).paired, isFalse);
    expect(boardStore.readIdentity(), isNull);
  });

  test('the code never appears anywhere the board could log it', () async {
    final ProviderContainer c = container();
    final KdsPairingController board = c.read(kdsPairingProvider.notifier);
    final PairingCode code = await registry.begin();

    board.select(advertisement());
    await board.join(code.value);

    // A sniffer once minted a credential from a code it saw on the wire. The
    // code is HKDF input and must exist only on the kiosk's screen and in the
    // hands of whoever typed it.
    expect('$code'.contains(code.value), isFalse);
    for (final String stored in keystore.values.values) {
      expect(stored.contains(code.value), isFalse);
    }
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
