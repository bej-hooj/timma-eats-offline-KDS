import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import '../../kds/state/kds_board.dart';

/// Where the TV speaks — chosen once by the manager (F2), kept in the TV's own
/// store so it survives a restart. Never leaves the device.
class TvSettings {
  const TvSettings({this.outputId, this.voiceId, this.monitorId});

  final String? outputId;
  final String? voiceId;

  /// The screen this window covers; null = the surface's default.
  final String? monitorId;
}

class TvSettingsController extends Notifier<TvSettings> {
  static const String outputKey = 'tv.audio_output';
  static const String voiceKey = 'tv.voice';
  static const String monitorKey = 'screen.monitor';

  PosStore get _store => ref.read(kdsStoreProvider);

  @override
  TvSettings build() => TvSettings(
    outputId: _clean(_store.readMeta(outputKey)),
    voiceId: _clean(_store.readMeta(voiceKey)),
    monitorId: _clean(_store.readMeta(monitorKey)),
  );

  /// Null → back to the Windows default output.
  void chooseOutput(String? id) {
    _store.writeMeta(outputKey, id ?? '');
    state = TvSettings(outputId: _clean(id), voiceId: state.voiceId, monitorId: state.monitorId);
  }

  /// Null → the system's default voice.
  void chooseVoice(String? id) {
    _store.writeMeta(voiceKey, id ?? '');
    state = TvSettings(outputId: state.outputId, voiceId: _clean(id), monitorId: state.monitorId);
  }

  /// Null → back to the surface's default screen.
  void chooseMonitor(String? id) {
    _store.writeMeta(monitorKey, id ?? '');
    state = TvSettings(outputId: state.outputId, voiceId: state.voiceId, monitorId: _clean(id));
  }

  static String? _clean(String? v) => v == null || v.isEmpty ? null : v;
}

final NotifierProvider<TvSettingsController, TvSettings> tvSettingsProvider =
    NotifierProvider<TvSettingsController, TvSettings>(TvSettingsController.new);
