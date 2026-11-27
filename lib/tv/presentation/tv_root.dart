import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import '../../kds/pairing/pairing_screen.dart';
import '../../kds/state/kds_board.dart';
import 'tv_app.dart';

/// Pairing, then the TV — no view picker (mirror of `KdsRoot`). The TV pairs
/// to the borne once, as its own board, with its own store (`kds-tv.db`).
class TvRoot extends ConsumerWidget {
  const TvRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PosDeviceIdentity? identity = ref.watch(kdsIdentityProvider);
    return TvApp(home: identity == null ? const KdsPairingScreen() : null);
  }
}
