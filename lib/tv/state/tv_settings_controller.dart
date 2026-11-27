import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import '../../kds/state/kds_board.dart';

/// Where the TV speaks — chosen once by the manager (F2), kept in the TV's own
/// store so it survives a restart. Never leaves the device.
class TvSettings {
  const TvSettings({this.outputId, this.voiceId});

  final String? outputId;
  final String? voiceId;
}

class TvSettingsController extends Notifier<TvSettings> {
  static const String outputKey = 'tv.audio_output';
  static const String voiceKey = 'tv.voice';

  PosStore get _store => ref.read(kdsStoreProvider);

  @override
  TvSettings build() => TvSettings(
    outputId: _clean(_store.readMeta(outputKey)),
    voiceId: _clean(_store.readMeta(voiceKey)),
  );

  /// Null → back to the Windows default output.
  void chooseOutput(String? id) {
    _store.writeMeta(outputKey, id ?? '');
    state = TvSettings(outputId: _clean(id), voiceId: state.voiceId);
  }

  /// Null → the system's default voice.
  void chooseVoice(String? id) {
    _store.writeMeta(voiceKey, id ?? '');
    state = TvSettings(outputId: state.outputId, voiceId: _clean(id));
  }

  static String? _clean(String? v) => v == null || v.isEmpty ? null : v;
}

final NotifierProvider<TvSettingsController, TvSettings> tvSettingsProvider =
    NotifierProvider<TvSettingsController, TvSettings>(TvSettingsController.new);
