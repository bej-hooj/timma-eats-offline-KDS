import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/design/time_util.dart';
import 'kds/kds_app.dart';
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
  final PosDeviceIdentity identity = store.readIdentity()!;

  runApp(
    ProviderScope(
      overrides: [
        kdsEngineProvider.overrideWithValue(
          PosEngine(store: store, identity: identity),
        ),
      ],
      child: const KdsApp(),
    ),
  );
}
