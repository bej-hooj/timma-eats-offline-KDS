import 'package:flutter_test/flutter_test.dart';
import 'package:timma_kds/launch/kds_surface.dart';

void main() {
  test('no argument is the kitchen board', () {
    expect(KdsSurfaceArgs.parse(const <String>[]), KdsSurface.kitchen);
  });

  test('only the exact flag makes the TV', () {
    expect(KdsSurfaceArgs.parse(const <String>['--surface=tv']), KdsSurface.tv);
    expect(KdsSurfaceArgs.parse(const <String>['--surface=TV']), KdsSurface.kitchen);
    expect(KdsSurfaceArgs.parse(const <String>['--surface', 'tv']), KdsSurface.kitchen);
  });

  test('each surface has its own store; the kitchen keeps kds.db', () {
    expect(KdsSurfaceArgs.storeFileName(KdsSurface.kitchen), 'kds.db');
    expect(KdsSurfaceArgs.storeFileName(KdsSurface.tv), 'kds-tv.db');
  });

  test('the kitchen TV has its own flag and store', () {
    expect(KdsSurfaceArgs.parse(const <String>['--surface=kitchen-tv']), KdsSurface.kitchenTv);
    expect(KdsSurfaceArgs.storeFileName(KdsSurface.kitchenTv), 'kds-cuisine-tv.db');
    expect(
      KdsSurface.values.map(KdsSurfaceArgs.storeFileName).toSet(),
      hasLength(KdsSurface.values.length),
    );
    expect(KdsSurfaceArgs.isDisplay(KdsSurface.kitchen), isFalse);
    expect(KdsSurfaceArgs.isDisplay(KdsSurface.tv), isTrue);
    expect(KdsSurfaceArgs.isDisplay(KdsSurface.kitchenTv), isTrue);
  });
}
