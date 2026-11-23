import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';
import 'package:pos_link/pos_link.dart';
import 'package:pos_link_flutter/pos_link_flutter.dart';

import '../pairing/pairing_controller.dart';
import '../menu/kds_dish_photos.dart';
import '../state/kds_board.dart';

/// Where the hub was last seen, remembered across restarts.
///
/// ⚠ **Pairing used to store an identity, a credential and a branch secret —
/// and not the one fact needed to use any of them.** A board that restarted had
/// everything required to authenticate and no idea what address to authenticate
/// *to*, so the kitchen came back from a reboot permanently blank while the
/// kiosk sat two metres away with its socket open. The address is written at
/// the moment pairing succeeds and re-read here.
abstract final class KdsHubAddress {
  static const String _hostKey = 'link.hub.host';
  static const String _portKey = 'link.hub.port';
  static const String _labelKey = 'link.hub.label';

  static void remember(
    PosStore store, {
    required HubEndpoint endpoint,
    required String label,
  }) {
    store.writeMeta(_hostKey, endpoint.host);
    store.writeMeta(_portKey, '${endpoint.port}');
    store.writeMeta(_labelKey, label);
  }

  static HubEndpoint? read(PosStore store) {
    final String? host = store.readMeta(_hostKey);
    final int? port = int.tryParse(store.readMeta(_portKey) ?? '');
    if (host == null || host.isEmpty || port == null) {
      return null;
    }
    return HubEndpoint(host: host, port: port);
  }

  static String? label(PosStore store) => store.readMeta(_labelKey);
}

@immutable
class KdsLinkState {
  const KdsLinkState({
    this.link = const LinkState.offline(),
    this.endpoint,
    this.searching = false,
    this.boardsReceived = 0,
  });

  /// What the badge renders. Owned by `pos_core` so the KDS, the kiosk and the
  /// relay all answer "is the other tablet there?" the same way.
  final LinkState link;

  final HubEndpoint? endpoint;

  /// The board is hunting for a hub whose address it does not know — after a
  /// router handed the kiosk a new DHCP lease, for instance.
  final bool searching;

  /// Snapshots applied since launch. Diagnostic, and the honest answer to "has
  /// this board ever heard from the kiosk?" — which `link.health` alone cannot
  /// give, because a socket can be up before a single board has crossed it.
  final int boardsReceived;

  bool get connected => link.isUsable;

  KdsLinkState copyWith({
    LinkState? link,
    HubEndpoint? endpoint,
    bool? searching,
    int? boardsReceived,
  }) => KdsLinkState(
    link: link ?? this.link,
    endpoint: endpoint ?? this.endpoint,
    searching: searching ?? this.searching,
    boardsReceived: boardsReceived ?? this.boardsReceived,
  );
}

/// Holds the board's socket to the kiosk hub: snapshots in, intents out.
///
/// ⚠ **This did not exist.** The board paired, wrote its credential, dropped
/// into service — and never opened a socket. Every phrase in the plan about the
/// kitchen receiving orders described a connection nothing constructed, so a
/// perfectly paired kitchen showed an empty board for ever, and a cook tapping
/// *Prêt* advanced a row in a local database no other device would ever read.
/// Two directions were missing, not one:
///
/// * **down** — `BoardSnapshot.applyTo(engine)` merges what the hub knows;
/// * **up** — an [OutboxDrain] over the same socket carries the cook's
///   transitions back, because `PosEngine.advance` queues an envelope addressed
///   to the hub and nothing was draining that queue.
class KdsLinkController extends Notifier<KdsLinkState> {
  LanSocketTransport? _transport;
  OutboxDrain? _drain;
  StreamSubscription<LinkState>? _links;
  NsdHubDiscovery? _discovery;
  StreamSubscription<HubAdvertisement>? _browse;
  Timer? _pump;
  bool _disposed = false;
  bool _starting = false;

  /// One reconnect attempt at a time. Without this the 3-second pump would pile
  /// attempts on top of a socket that is already taking ten seconds to fail.
  bool _reconnecting = false;

  /// The board pushes its own work up on this cadence. Fast, because it is a
  /// local socket on the same wifi and an unsent `ready` is a customer standing
  /// at a counter — and cheap, because an empty outbox is one indexed query.
  static const Duration pumpEvery = Duration(seconds: 3);

  @override
  KdsLinkState build() {
    ref.onDispose(() {
      _disposed = true;
      unawaited(stop());
    });
    return const KdsLinkState();
  }

  /// Opens the socket. Idempotent, and safe to call before pairing — an
  /// unpaired board simply has nothing to connect to yet.
  Future<void> start() async {
    if (_transport != null || _starting || _disposed) {
      return;
    }
    final PosDeviceIdentity? identity = ref.read(kdsIdentityProvider);
    if (identity == null) {
      return;
    }
    _starting = true;
    try {
      final PosStore store = ref.read(kdsStoreProvider);
      final DeviceCredential? credential = await ref
          .read(kdsCredentialVaultProvider)
          .read(identity.deviceId);
      if (credential == null) {
        // Paired identity, no credential: a half-provisioned board. It cannot
        // authenticate, and pretending otherwise would loop a socket forever.
        debugPrint('[KdsLink] no stored credential — re-pairing is required');
        return;
      }

      HubEndpoint? endpoint = KdsHubAddress.read(store);
      endpoint ??= await _rediscover(identity.branchId);
      if (endpoint == null) {
        return;
      }

      final LanSocketTransport transport = LanSocketTransport(
        endpoint: endpoint,
        identity: identity,
        credential: credential,
        onSnapshot: _apply,
      );
      _transport = transport;
      _drain = OutboxDrain(store: store, sink: transport);
      _links = transport.linkStates.listen((LinkState link) {
        if (!_disposed) {
          state = state.copyWith(link: link);
        }
      });
      state = state.copyWith(endpoint: endpoint, searching: false);

      // The transport reconnects on its own backoff, so a first failure is not
      // fatal: the kiosk may simply not be up yet. What must not happen is the
      // board giving up and needing a human to restart it.
      unawaited(_connect(transport));

      _pump = Timer.periodic(pumpEvery, (_) => unawaited(pump()));
    } on Object catch (error) {
      debugPrint('[KdsLink] could not start: $error');
    } finally {
      _starting = false;
    }
  }

  Future<void> _connect(LanSocketTransport transport) async {
    try {
      await transport.connect();
      await pump();
    } on LinkProtocolException catch (error) {
      // ⚠ **A refusal is not an outage.** The kiosk answered, and its answer
      // was "I have never heard of you" — which is exactly what a reinstalled
      // kiosk says to a board whose identity survived in `kds.db`. Retrying
      // that for ever is how a tablet ends up parked on empty lanes with no
      // route back to the pairing screen. It is unpaired; it should say so.
      if (error.code == LinkProtocolErrorCode.unauthenticated ||
          error.code == LinkProtocolErrorCode.badSignature) {
        debugPrint('[KdsLink] the kiosk refused this board — pairing again');
        await stop();
        if (!_disposed) {
          ref.read(kdsIdentityProvider.notifier).requirePairing();
        }
        return;
      }
      debugPrint('[KdsLink] hub not reachable yet — will keep retrying');
    } on Object {
      // Counted by the link monitor and rendered as the offline badge. Not
      // surfaced as an error string: "connection refused" is not something a
      // cook can act on, and the badge already says the truth.
      debugPrint('[KdsLink] hub not reachable yet — will keep retrying');
    }
  }

  /// mDNS, for the board that has never been told an address or whose kiosk
  /// moved. Bounded: a browse that runs for ever on a router with multicast off
  /// is a background radio nobody asked for.
  /// How long the link may fail before the stored address is doubted.
  ///
  /// ⚠ Measured in TIME, not pump ticks. A connect attempt holds
  /// `_reconnecting` for its whole request timeout, so most ticks are skipped
  /// while one is in flight — counting ticks made this take minutes instead of
  /// the minute it reads as.
  static const Duration _offlineBeforeRediscovery = Duration(seconds: 45);

  DateTime? _offlineSince;

  /// Looks for this branch's borne at a new address and moves the link there.
  ///
  /// Does nothing unless discovery actually finds a DIFFERENT endpoint: a
  /// kitchen whose kiosk is merely switched off must keep waiting for it, not
  /// tear its own link down every minute.
  Future<void> _relocate() async {
    final PosDeviceIdentity? identity = ref.read(kdsIdentityProvider);
    final LanSocketTransport? current = _transport;
    if (identity == null || current == null || _disposed) {
      return;
    }
    final HubEndpoint? found = await _rediscover(identity.branchId);
    if (found == null || _disposed) {
      return;
    }
    if (found.host == current.endpoint.host &&
        found.port == current.endpoint.port) {
      return;
    }
    debugPrint('[KdsLink] the borne moved — following it to a new address');
    final PosStore store = ref.read(kdsStoreProvider);
    KdsHubAddress.remember(
      store,
      endpoint: found,
      // The borne's name has not changed, only where it lives.
      label: KdsHubAddress.label(store) ?? 'Borne',
    );
    await stop();
    await start();
  }

  Future<HubEndpoint?> _rediscover(String branchId) async {
    state = state.copyWith(searching: true);
    final Completer<HubEndpoint?> found = Completer<HubEndpoint?>();
    try {
      final NsdHubDiscovery discovery = NsdHubDiscovery();
      _discovery = discovery;
      _browse = discovery.discover().listen(
        (HubAdvertisement hub) {
          // **Only this board's own restaurant.** A shared building with two
          // TIMMA kiosks on one wifi must never cross-wire two kitchens.
          if (hub.branchId == branchId && !found.isCompleted) {
            found.complete(hub.endpoint);
          }
        },
        onError: (Object _) {
          if (!found.isCompleted) {
            found.complete(null);
          }
        },
      );
      final HubEndpoint? endpoint = await found.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
      if (endpoint != null) {
        KdsHubAddress.remember(
          ref.read(kdsStoreProvider),
          endpoint: endpoint,
          label: KdsHubAddress.label(ref.read(kdsStoreProvider)) ?? 'Borne',
        );
      }
      return endpoint;
    } on Object {
      return null;
    } finally {
      await _browse?.cancel();
      _browse = null;
      await _discovery?.close();
      _discovery = null;
      if (!_disposed) {
        state = state.copyWith(searching: false);
      }
    }
  }

  /// A board arrived. Merge it, then let the board controller re-read — which
  /// is also what evaluates the alarm, so a ticket cannot land silently.
  Future<void> _apply(BoardSnapshot snapshot) async {
    if (_disposed) {
      return;
    }
    try {
      snapshot.applyTo(ref.read(kdsEngineProvider));
    } on Object catch (error) {
      debugPrint('[KdsLink] a snapshot would not merge: $error');
      return;
    }
    // The dashboard's photographs, resolved by the borne from its active
    // bundle. Absorbed BEFORE the board re-reads so the cards that are about
    // to be built already know their pictures.
    ref.read(kdsDishPhotosProvider.notifier).absorb(snapshot.photos);
    state = state.copyWith(boardsReceived: state.boardsReceived + 1);
    ref.read(kdsBoardProvider.notifier).refresh();
  }

  /// Pushes queued transitions to the hub. Called on the timer and immediately
  /// after a cook taps, so *Prêt* is not held for up to three seconds behind a
  /// tick.
  Future<void> pump() async {
    final OutboxDrain? drain = _drain;
    if (drain == null) {
      return;
    }

    // ⚠ **A refusal has to be caught on every attempt, not just the first.**
    // `connect()` was called once at start-up, so only that one attempt's error
    // ever reached the handler that sends a refused board back to pairing.
    // `LanSocketTransport` then reconnects on its own backoff for ever, and
    // those attempts fail privately — which is exactly the field case: a board
    // that was working, a kiosk that was reinstalled, and a tablet parked on
    // *Hors ligne* with no way back. Reported from the device, twice.
    //
    // `connect()` returns the in-flight future when one exists, so this waits
    // on the transport's own attempt rather than racing it.
    // ⚠ **Not awaited.** `connect()` can sit for the full request timeout, and
    // this method is also what a cook's tap calls to push a transition — so
    // awaiting it here would stall *Prêt* behind a dead socket for ten seconds,
    // and it hung the link tests outright. The reconnect runs alongside the
    // drain; when it fails with a refusal, `_connect` unpairs the board from
    // its own continuation.
    final LanSocketTransport? transport = _transport;
    if (transport != null && !state.connected && !_reconnecting) {
      _reconnecting = true;
      _offlineSince ??= DateTime.now();
      unawaited(_connect(transport).whenComplete(() => _reconnecting = false));
      // ⚠⚠ **The stored address can simply be wrong, and for ever.**
      //
      // `start()` uses `KdsHubAddress` and only falls back to discovery when
      // there is none. Move the two tablets to another wifi — which the owner
      // did today — and the borne gets a new lease, so the board dials a dead
      // address until somebody re-pairs it, with nothing on screen to say
      // why. Same on any router reboot that reshuffles DHCP.
      //
      // After a minute of failure the address is treated as suspect and mDNS
      // is asked again. The credential is untouched: this looks for the SAME
      // branch's hub at a new address, and finding one is not pairing.
      final DateTime? since = _offlineSince;
      if (since != null &&
          DateTime.now().difference(since) >= _offlineBeforeRediscovery) {
        _offlineSince = null;
        unawaited(_relocate());
      }
    } else if (state.connected) {
      _offlineSince = null;
    }
    try {
      await drain.drainOnce();
    } on Object {
      // Retried on the next tick. An outbox that cannot send is exactly the
      // offline case this whole design is built to survive.
    }
  }

  Future<void> stop() async {
    _pump?.cancel();
    _pump = null;
    await _links?.cancel();
    _links = null;
    await _browse?.cancel();
    _browse = null;
    await _discovery?.close();
    _discovery = null;
    final LanSocketTransport? transport = _transport;
    _transport = null;
    _drain = null;
    await transport?.close();
  }
}

final NotifierProvider<KdsLinkController, KdsLinkState> kdsLinkProvider =
    NotifierProvider<KdsLinkController, KdsLinkState>(KdsLinkController.new);
