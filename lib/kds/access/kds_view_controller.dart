import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import '../state/kds_board.dart';
import 'kds_view.dart';

/// The chosen [KdsView], kept in this tablet's own store so it survives a
/// restart and works offline. Never leaves the device.
class KdsViewController extends Notifier<String?> {
  static const String metaKey = 'kds.view';

  @override
  String? build() => KdsView.parse(_store.readMeta(metaKey));

  // Through the engine, which every shell and test provides.
  PosStore get _store => ref.read(kdsEngineProvider).store;

  void choose(String view) {
    final String? valid = KdsView.parse(view);
    if (valid == null) {
      return;
    }
    _store.writeMeta(metaKey, valid);
    state = valid;
  }

  /// « Changer de vue » — back to the picker.
  void clear() {
    _store.writeMeta(metaKey, '');
    state = null;
  }
}

final NotifierProvider<KdsViewController, String?> kdsViewProvider =
    NotifierProvider<KdsViewController, String?>(KdsViewController.new);
