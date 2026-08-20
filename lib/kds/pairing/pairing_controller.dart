import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_link/pos_link.dart';
import 'package:pos_link_flutter/pos_link_flutter.dart';

import '../link/kds_link.dart';
import '../state/kds_board.dart';

/// Stable codes the screen turns into French. Never an exception's own text.
abstract final class KdsPairingError {
  static const String notFound = 'pairing_hub_not_found';
  static const String unreachable = 'pairing_hub_unreachable';
  static const String badCode = 'pairing_bad_code';
  static const String expired = 'pairing_expired';
  static const String refused = 'pairing_refused';
  static const String storeFailed = 'pairing_store_failed';
}

@immutable
class KdsPairingState {
  const KdsPairingState({
    this.searching = false,
    this.hubs = const <HubAdvertisement>[],
    this.selected,
    this.joining = false,
    this.paired = false,
    this.error,
  });

  final bool searching;
  final List<HubAdvertisement> hubs;
  final HubAdvertisement? selected;
  final bool joining;
  final bool paired;
  final String? error;

  KdsPairingState copyWith({
    bool? searching,
    List<HubAdvertisement>? hubs,
    HubAdvertisement? selected,
    bool? joining,
    bool? paired,
    String? error,
    bool clearError = false,
    bool clearSelected = false,
  }) => KdsPairingState(
    searching: searching ?? this.searching,
    hubs: hubs ?? this.hubs,
    selected: clearSelected ? null : (selected ?? this.selected),
    joining: joining ?? this.joining,
    paired: paired ?? this.paired,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Finds a kiosk on the wifi and joins it.
///
/// **The board is claimed by the branch that pairs it.** A tablet out of the box
/// has no branch of its own — it cannot, because a branch is something a
/// restaurant grants, not something a device asserts. So the identity is written
/// at the moment of pairing, from the hub the manager approved: the six digits
/// prove a human was standing at that kiosk, and the hub's proof over the shared
/// key proves the kiosk is the one that showed them (§23.9).
class KdsPairingController extends Notifier<KdsPairingState> {
  StreamSubscription<HubAdvertisement>? _browse;
  NsdHubDiscovery? _discovery;

  /// mDNS browsing outlives the screen that started it, so the teardown path
  /// can run after this notifier is gone. Writing `state` then throws.
  bool _disposed = false;

  @override
  KdsPairingState build() {
    ref.onDispose(() {
      _disposed = true;
      unawaited(stopSearch());
    });
    return const KdsPairingState();
  }

  /// Browses `_timma-pos._tcp`. Each hub found is added as it appears, because
  /// on a busy network the first answer can be seconds ahead of the second.
  Future<void> search() async {
    await stopSearch();
    state = state.copyWith(
      searching: true,
      hubs: <HubAdvertisement>[],
      clearError: true,
    );
    try {
      final NsdHubDiscovery discovery = NsdHubDiscovery();
      _discovery = discovery;
      _browse = discovery.discover().listen(
        (HubAdvertisement hub) {
          final List<HubAdvertisement> found = <HubAdvertisement>[
            ...state.hubs.where(
              (HubAdvertisement known) => known.hubDeviceId != hub.hubDeviceId,
            ),
            hub,
          ];
          state = state.copyWith(hubs: found);
        },
        onError: (Object _) =>
            state = state.copyWith(error: KdsPairingError.notFound),
      );
    } on Object {
      state = state.copyWith(searching: false, error: KdsPairingError.notFound);
    }
  }

  Future<void> stopSearch() async {
    await _browse?.cancel();
    _browse = null;
    final NsdHubDiscovery? discovery = _discovery;
    _discovery = null;
    await discovery?.close();
    if (!_disposed && state.searching) {
      state = state.copyWith(searching: false);
    }
  }

  /// The fallback for a router with multicast switched off: the manager reads
  /// the address off the kiosk's own screen and types it here. The hub's
  /// `/health` then names the branch and the kiosk, so the board can show a
  /// human what it is about to join before any code is entered.
  Future<void> findByAddress(String host, int port) async {
    state = state.copyWith(searching: true, clearError: true);
    try {
      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final HttpClientRequest request = await client
          .getUrl(Uri.parse('http://$host:$port/health'))
          .timeout(const Duration(seconds: 5));
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final String raw = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode != HttpStatus.ok) {
        throw const SocketException('health');
      }
      final Map<String, dynamic> body = jsonDecode(raw) as Map<String, dynamic>;
      final String? branchId = body['branch_id'] as String?;
      final String? hubDeviceId = body['hub_device_id'] as String?;
      if (branchId == null || hubDeviceId == null) {
        throw const FormatException('health');
      }
      final HubAdvertisement hub = HubAdvertisement(
        endpoint: HubEndpoint(host: host, port: port),
        hubDeviceId: hubDeviceId,
        hubLabel: (body['hub_label'] as String?) ?? host,
        branchId: branchId,
      );
      state = state.copyWith(
        searching: false,
        hubs: <HubAdvertisement>[hub],
        selected: hub,
        clearError: true,
      );
    } on Object {
      state = state.copyWith(
        searching: false,
        error: KdsPairingError.unreachable,
      );
    }
  }

  void select(HubAdvertisement hub) =>
      state = state.copyWith(selected: hub, clearError: true);

  void deselect() => state = state.copyWith(clearSelected: true);

  /// Runs the handshake and, only on success, writes identity + credential +
  /// branch secret.
  ///
  /// Nothing is persisted until every step has succeeded: a half-provisioned
  /// board — an identity with no credential, or a credential with no secret —
  /// would come back after a restart looking paired and be unable to verify a
  /// single slip.
  Future<void> join(String code) async {
    final HubAdvertisement? hub = state.selected;
    if (hub == null || state.joining) {
      return;
    }
    state = state.copyWith(joining: true, clearError: true);

    final PosStore store = ref.read(kdsStoreProvider);
    final PosDeviceIdentity identity = PosDeviceIdentity(
      // A fresh identity per pairing. Reusing one across restaurants is how a
      // board ends up authenticated to a branch nobody granted it.
      deviceId: PosIds.newDeviceId(),
      branchId: hub.branchId,
      role: PosDeviceRole.kds,
      label: _label(),
    );

    try {
      final PairingResult result = await LanPairingClient.pair(
        endpoint: hub.endpoint,
        identity: identity,
        code: code,
      );

      await ref.read(kdsCredentialVaultProvider).write(result.credential);
      // ⚠ **`adopt`, not `writeOnce` — and only here.** A kiosk that has been
      // reinstalled mints a new branch secret, and `writeOnce` then refuses it
      // as a conflict: the board reported *Impossible d'enregistrer la clé de
      // sécurité sur cette tablette*, blaming its own keystore, and on iOS the
      // keychain survives an app uninstall so reinstalling the board did not
      // clear it either. Two devices, no way to make them work together from
      // the devices. It stranded real hardware twice.
      //
      // The authority to replace it is what this very handshake just proved: a
      // manager read six digits off the kiosk's screen and typed them here,
      // inside the pairing window, with the code never crossing the wire
      // (§23.9). That is the recovery ceremony the vault's doc has always
      // required. Nothing else in either app may call `adopt`.
      await ref
          .read(kdsSecretVaultProvider)
          .adopt(branchId: hub.branchId, secret: result.collectionSecret);
      store.writeIdentity(identity);
      // ⚠ **And the address.** Everything above is what proves *who* this board
      // is; without this line it would come back from a restart perfectly
      // provisioned and with nowhere to connect, which is how a paired kitchen
      // ends up permanently blank two metres from a running kiosk.
      KdsHubAddress.remember(
        store,
        endpoint: hub.endpoint,
        label: hub.hubLabel,
      );
      // Only now does the rest of the app learn it has an identity, so a
      // half-finished pairing can never present itself as a working board.
      ref.read(kdsIdentityProvider.notifier).adopt();
      // And the socket opens straight away: a manager who has just paired a
      // tablet expects the first order to land, not to have to restart it.
      unawaited(ref.read(kdsLinkProvider.notifier).start());

      state = state.copyWith(joining: false, paired: true);
    } on LinkProtocolException catch (error) {
      state = state.copyWith(
        joining: false,
        // The hub distinguishes a *stale window* from *wrong digits*, and only
        // one of those is the manager's fault. Collapsing both into "code
        // refused" sent people back to re-read six digits they had typed
        // correctly, because the window had simply timed out while they walked
        // from the borne to the kitchen.
        error: switch (error.code) {
          // Nothing to claim, or too many tries: in every one of these the
          // remedy is the same single sentence — go back and ask the borne for
          // a new code.
          PairingErrorCode.expired ||
          PairingErrorCode.unavailable ||
          PairingErrorCode.attemptsExceeded => KdsPairingError.expired,
          PairingErrorCode.incorrectCode ||
          LinkProtocolErrorCode.badPairing => KdsPairingError.badCode,
          _ => KdsPairingError.refused,
        },
      );
    } on BranchCollectionSecretVaultException {
      state = state.copyWith(
        joining: false,
        error: KdsPairingError.storeFailed,
      );
    } on Object {
      // ⚠ **"Borne injoignable" was a lie the kitchen could not act on.** An
      // expired code does not fail as a protocol error: the kiosk simply has no
      // pairing window open, the socket goes away, and everything landed in
      // this catch — so the borne said *Code expiré* while the cuisine, two
      // metres away, told a manager to go and check the wifi. Asking `/health`
      // separates the two honestly: if the kiosk answers, the network is fine
      // and the code is the problem.
      final bool reachable = await _reachable(hub.endpoint);
      state = state.copyWith(
        joining: false,
        error: reachable
            ? KdsPairingError.expired
            : KdsPairingError.unreachable,
      );
    }
  }

  /// Is the hub answering at all? One short HTTP call, never a retry loop: this
  /// runs while a manager is standing at a tablet waiting for a message.
  Future<bool> _reachable(HubEndpoint endpoint) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final HttpClientRequest request = await client
          .getUrl(endpoint.healthUri)
          .timeout(const Duration(seconds: 3));
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// What the kiosk shows the manager when asking them to approve this device.
  /// A human has to recognise it, so it names the product, not a UUID.
  String _label() => 'Cuisine';
}

/// The keystore-backed vaults, injectable so the pairing handshake can be proven
/// on a host without a platform channel.
///
/// They were constructed inline with `.platform()`, which meant the one path
/// that decides whether two tablets can work together could only be tested by
/// hand on two devices. A seam here is the difference between a proof and a
/// hope.
final Provider<KdsCredentialVault> kdsCredentialVaultProvider =
    Provider<KdsCredentialVault>((Ref ref) => KdsCredentialVault.platform());

final Provider<BranchCollectionSecretVault> kdsSecretVaultProvider =
    Provider<BranchCollectionSecretVault>(
      (Ref ref) => BranchCollectionSecretVault.platform(),
    );

final NotifierProvider<KdsPairingController, KdsPairingState>
kdsPairingProvider = NotifierProvider<KdsPairingController, KdsPairingState>(
  KdsPairingController.new,
);
