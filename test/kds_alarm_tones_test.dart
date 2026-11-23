import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timma_kds/kds/audio/kds_alarm_sink.dart';
import 'package:timma_kds/kds/domain/kds_alarm.dart';

/// Owner, 2026-11-23: *"in the kitchen app the alarm on the «À encaisser» step
/// should be different sound from the «Nouvelles» step"*.
///
/// The register split is tested in `kds_board_test.dart`; this is the other
/// half, and the half a reviewer would skip. A board can hold three registers
/// and still play one tone for two of them — the switch compiles, the suite
/// passes, and the kitchen still cannot tell which job it is being called for.
void main() {
  test('every register has its own tone, and the file is really there', () {
    final Map<KdsAlarmRegister, String> assets = <KdsAlarmRegister, String>{
      for (final KdsAlarmRegister r in KdsAlarmRegister.values)
        r: AudioAlarmSink.assetFor(r),
    };

    expect(
      assets.values.toSet(),
      hasLength(KdsAlarmRegister.values.length),
      reason:
          'two registers sharing a file is two registers the kitchen '
          'cannot tell apart',
    );

    for (final MapEntry<KdsAlarmRegister, String> e in assets.entries) {
      // `audioplayers` resolves an AssetSource under `assets/`. A path that is
      // merely plausible fails at runtime on a shelf in a kitchen, which is
      // the one place nobody is watching a log.
      final File file = File('assets/${e.value}');
      expect(file.existsSync(), isTrue, reason: '${e.key} → ${file.path}');
      expect(
        file.lengthSync(),
        greaterThan(1000),
        reason: '${e.key} points at an empty file',
      );
    }
  });

  test('the tones are bundled, not just present on disk', () {
    // ⚠ An asset that exists in the repo and is missing from `pubspec.yaml`
    // ships as a silent alarm. Nothing else in the suite would notice.
    //
    // Read as text rather than parsed: `yaml` is not a dependency of this app
    // and adding one to a kitchen tablet's bundle to read its own manifest in
    // a test is the wrong trade.
    final List<String> lines = File(
      'pubspec.yaml',
    ).readAsLinesSync().map((String l) => l.trim()).toList();
    for (final KdsAlarmRegister r in KdsAlarmRegister.values) {
      final String asset = 'assets/${AudioAlarmSink.assetFor(r)}';
      expect(
        lines.any(
          (String l) =>
              l == '- $asset' ||
              (l.startsWith('- ') &&
                  l.endsWith('/') &&
                  asset.startsWith(l.substring(2))),
        ),
        isTrue,
        reason: '$asset is not declared in pubspec.yaml',
      );
    }
  });
}
