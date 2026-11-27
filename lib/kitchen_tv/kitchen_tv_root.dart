import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import '../display/display_chrome.dart';
import '../display/display_placement.dart';
import '../kds/kds_app.dart';
import '../kds/pairing/pairing_screen.dart';
import '../kds/presentation/board_screen.dart';
import '../kds/state/kds_board.dart';
import 'kitchen_tv_settings_dialog.dart';

/// The « Écran cuisine » (S6-B): pairing, then the kitchen board — the SAME
/// `KdsBoardScreen` the tablet shows, read-only (`kdsReadOnlyProvider`, set in
/// `main.dart`), full-screen on the back TV, F2 for its settings.
class KitchenTvRoot extends ConsumerWidget {
  const KitchenTvRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PosDeviceIdentity? identity = ref.watch(kdsIdentityProvider);
    return KdsApp(
      home: identity == null
          ? const KdsPairingScreen()
          : const _KitchenTvScreen(),
    );
  }
}

class _KitchenTvScreen extends StatelessWidget {
  const _KitchenTvScreen();

  @override
  Widget build(BuildContext context) => DisplayPlacement(
    child: DisplayChrome(
      onOpenSettings: () => unawaited(KitchenTvSettingsDialog.show(context)),
      child: const KdsBoardScreen(),
    ),
  );
}
