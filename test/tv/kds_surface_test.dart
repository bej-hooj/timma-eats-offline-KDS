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
}
