import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/design/time_util.dart';
import 'package:timma_kds/launch/kds_surface.dart';
import 'package:timma_kds/tv/presentation/tv_root.dart';
import 'kds/audio/kds_alarm_sink.dart';
import 'kds/kds_root.dart';
import 'kds/link/kds_link.dart';
import 'kds/state/kds_board.dart';

/// A borne that is switched off must not look like a crash.
///
/// ⚠ Measured on the kitchen Samsung 2026-11-23, with the borne off: the link
/// logged `hub not reachable yet — will keep retrying` exactly as designed,
/// and directly underneath it `E/flutter: Unhandled Exception:
/// WebSocketChannelException: Connection refused`. Every attempt, all night.
///
/// The transport observes every future it owns — the stream's `onError`, the
/// `ready` future and `sink.done` — and this one still escapes, because
/// `web_socket_channel` adds the failure to its own sink *after* the transport
/// has closed it, where nothing is left to receive it. It cannot be caught at
/// the call site; it arrives as an unhandled error on the isolate.
///
/// So it is handled here, **narrowly**: this one exception type, which on this
/// surface means exactly one thing — the borne is not answering yet, which the
/// offline badge is already saying. Everything else is rethrown to the default
/// handler untouched, because a board that swallowed its own crashes would be
/// a board nobody could debug.
void _swallowUnreachableHubErrors() {
  final bool Function(Object, StackTrace)? previous =
      PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (error.runtimeType.toString() == 'WebSocketChannelException') {
      debugPrint('[KdsLink] hub unreachable (socket closed): $error');
      return true;
    }
    return previous?.call(error, stack) ?? false;
  };
}

/// The kitchen board's entrypoint — the third surface in this repo, after the
/// customer app and the kiosk.
///
///     flutter run --target lib/kds_main.dart
///
/// Like the kiosk it initialises neither Supabase nor Hive: the KDS reads the
/// local store the hub feeds over the LAN or the relay, and **never writes
/// order state to Supabase itself** (§23.2 — one writer, no split-brain).
///
/// With [KdsSurfaceArgs.tvFlag] the same binary is the dining-room TV (S6):
/// its own store file, its own pairing, no kitchen alarm, [TvRoot] instead of
/// [KdsRoot]. Without it, the kitchen board starts exactly as before.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  TimeUtil.init();
  _swallowUnreachableHubErrors();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // The board stays awake: a kitchen tablet that sleeps mid-service is a board
  // nobody is reading.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final Directory dir = await getApplicationDocumentsDirectory();
  final KdsSurface surface = KdsSurfaceArgs.parse(args);
  final PosStore store = SqlitePosStore.open(
    '${dir.path}/${KdsSurfaceArgs.storeFileName(surface)}',
  );

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
        // The TV never rings the kitchen alarm: the cooks hear it on the PC.
        if (surface == KdsSurface.tv)
          kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink()),
      ],
      child: _BoardWithLink(surface: surface),
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
  const _BoardWithLink({required this.surface});

  /// Kitchen board or dining-room TV — both need the same link to the borne.
  final KdsSurface surface;

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
  Widget build(BuildContext context) =>
      widget.surface == KdsSurface.tv ? const TvRoot() : const KdsRoot();
}
