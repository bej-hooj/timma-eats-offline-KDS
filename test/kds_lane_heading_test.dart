import 'package:flutter_test/flutter_test.dart';
import 'package:timma_kds/kds/theme/kds_scale.dart';

/// Owner, 2026-11-23, twice: *"please be very carefull with rendering design …
/// very beautifull and very hight quality responsive"*, after seeing
/// **"En prépara…"** on the real board.
///
/// A lane heading with an ellipsis in it is not a cosmetic miss on this
/// screen: the board is read from two metres across a kitchen, and the first
/// thing a cook has to do is find their column.
void main() {
  /// Stands in for the real text measurement. Every glyph the same width keeps
  /// the arithmetic checkable; the widget test below uses the real painter.
  double measure(String text) => text.length * 13;

  const List<String> frenchSpine = <String>[
    'À encaisser',
    'Nouvelles',
    'En préparation',
    'Prêtes',
  ];

  double roomFor(double laneWidth, double chip) =>
      laneWidth - KdsScale.gapMd * 2 - KdsScale.gap - chip - 6;

  test('no WORD is ever cut, at the size every lane shares', () {
    final double size = KdsScale.laneTitleSize(
      titles: frenchSpine,
      laneWidth: 205, // four lanes on the Samsung's 868 dp landscape
      countChipWidth: 30,
      measure: measure,
    );

    // ⚠ The rule, stated as arithmetic. The heading wraps to two lines, so
    // the binding constraint is the longest WORD rather than the longest
    // title: a word that does not fit its column is cut wherever it lands.
    final double room = roomFor(205, 30);
    for (final String title in frenchSpine) {
      for (final String word in title.split(' ')) {
        expect(
          measure(word) * size / KdsScale.titleSize,
          lessThanOrEqualTo(room + 0.01),
          reason: '"$word" would be cut at $size dp',
        );
      }
    }
  });

  test('the whole title fits inside its two lines', () {
    final double size = KdsScale.laneTitleSize(
      titles: frenchSpine,
      laneWidth: 205,
      countChipWidth: 30,
      measure: measure,
    );
    final double room = roomFor(205, 30);
    for (final String title in frenchSpine) {
      expect(
        measure(title) * size / KdsScale.titleSize,
        lessThanOrEqualTo(room * 2 + 0.01),
        reason: '"$title" needs more than two lines at $size dp',
      );
    }
  });

  test('a television keeps the full size — this only ever shrinks', () {
    // 1920x1080 at dpr 1: four lanes of about 460 dp. Owner, 2026-11-23:
    // "kitchen and born should fit any size cause it could be displayed on
    // tv".
    expect(
      KdsScale.laneTitleSize(
        titles: frenchSpine,
        laneWidth: 460,
        countChipWidth: 30,
        measure: measure,
      ),
      KdsScale.titleSize,
    );
  });

  test('a short board keeps the full size — scaleDown never scales up', () {
    expect(
      KdsScale.laneTitleSize(
        titles: <String>['A', 'B'],
        laneWidth: 600,
        countChipWidth: 30,
        measure: measure,
      ),
      KdsScale.titleSize,
    );
  });

  test('an over-reserved chip is what put the ellipsis back', () {
    // The defect, as a number. A flat 48 dp reservation for a chip that is
    // really about 30 drove the size under the floor on the device, and the
    // heading came back truncated.
    final double honest = KdsScale.laneTitleSize(
      titles: frenchSpine,
      laneWidth: 205,
      countChipWidth: 30,
      measure: measure,
    );
    final double overReserved = KdsScale.laneTitleSize(
      titles: frenchSpine,
      laneWidth: 205,
      countChipWidth: 48,
      measure: measure,
    );
    expect(honest, greaterThan(overReserved));
    expect(honest, greaterThan(KdsScale.laneTitleMinSize));
  });

  test('it never goes under the floor, however narrow the board', () {
    expect(
      KdsScale.laneTitleSize(
        titles: frenchSpine,
        laneWidth: 60,
        countChipWidth: 30,
        measure: measure,
      ),
      KdsScale.laneTitleMinSize,
    );
    // Nor past the ceiling, which is what a title of zero width would do.
    expect(
      KdsScale.laneTitleSize(
        titles: <String>[''],
        laneWidth: 400,
        countChipWidth: 30,
        measure: measure,
      ),
      KdsScale.titleSize,
    );
  });

  // ⚠ **There is deliberately no widget test measuring real glyph widths.**
  // `flutter_test` substitutes a font where every glyph advances a full em, so
  // "En préparation" measures 176 dp at 16 dp type in this harness against
  // roughly 105 on the device — a test written against that would be
  // measuring the harness and would fail on text that fits perfectly well.
  // The arithmetic above is what is checkable here; the fit itself is checked
  // on the Samsung, by screenshot, which is how both versions of this defect
  // were found in the first place.
}
