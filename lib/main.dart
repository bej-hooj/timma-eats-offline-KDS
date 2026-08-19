import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/design/time_util.dart';
import 'kds/kds_root.dart';
import 'kds/link/kds_link.dart';
import 'kds/state/kds_board.dart';

/// The kitchen board's entrypoint — the third surface in this repo, after the
/// customer app and the kiosk.
///
///     flutter run --target lib/kds_main.dart
///
/// Like the kiosk it initialises neither Supabase nor Hive: the KDS reads the
/// local store the hub feeds over the LAN or the relay, and **never writes
/// order state to Supabase itself** (§23.2 — one writer, no split-brain).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TimeUtil.init();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // The board stays awake: a kitchen tablet that sleeps mid-service is a board
  // nobody is reading.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final Directory dir = await getApplicationDocumentsDirectory();
  final PosStore store = SqlitePosStore.open('${dir.path}/kds.db');

  // **An unpaired tablet has no identity, and that is not a crash** — and it is
  // no longer a dead end either. The store is opened and handed to the app
  // whether or not this board has been paired, so the pairing screen has
  // somewhere to write the identity it earns.
  runApp(
    ProviderScope(
      overrides: [
        kdsStoreProvider.overrideWithValue(store),
        // ⚠ **One container, not a nested scope.** Overriding this inside a
        // child `ProviderScope` would rebuild `kdsBoardProvider` there while
        // the link controller kept the parent's copy — so an arriving snapshot
        // would refresh a board no screen was watching, and the kitchen would
        // stay blank while every log line said the order had been merged.
        kdsIntentPublisherProvider.overrideWith(
          (Ref ref) =>
              () => unawaited(ref.read(kdsLinkProvider.notifier).pump()),
        ),
      ],
      child: const _BoardWithLink(),
    ),
  );
}

/// Opens the socket to the kiosk as soon as the first frame is up.
///
/// ⚠ **A paired board used to connect to nothing at all.** Pairing wrote an
/// identity, a credential and a branch secret, then dropped into service
/// without ever constructing a transport — so a kitchen that had been paired
/// correctly, by a manager who did everything right, sat in front of empty
/// lanes for ever while the kiosk two metres away took orders. Both halves live
/// here, in the production composition root and not in the shell widget, for
/// the same reason the kiosk's hub does: a widget test builds the app directly,
/// and a real socket inside a test is a pending timer that fails the suite for
/// reasons that have nothing to do with the test.
class _BoardWithLink extends ConsumerStatefulWidget {
  const _BoardWithLink();

  @override
  ConsumerState<_BoardWithLink> createState() => _BoardWithLinkState();
}

class _BoardWithLinkState extends ConsumerState<_BoardWithLink> {
  @override
  void initState() {
    super.initState();
    // Safe before pairing: with no identity this returns immediately, and
    // pairing starts the link itself the moment it earns one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(kdsLinkProvider.notifier).start());
    });
  }

  @override
  Widget build(BuildContext context) => const KdsRoot();
}
