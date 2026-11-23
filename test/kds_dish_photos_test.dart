import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timma_kds/kds/menu/kds_dish_photos.dart';
import 'package:timma_kds/kds/theme/kds_scale.dart';

/// Owner, 2026-11-23: *"i want the kitchen dish on the kitchen pipeline to have
/// dishes images. Of cause they are data-driven from the dashboard (database)
/// when the kitchen is connected to the internet"*.
///
/// The photographs come down on the board frame (proven in `pos_link`'s
/// `board_photos_test.dart`). This is the kitchen half: what it keeps, what it
/// draws while a picture is in flight, and what it does when there is no
/// internet at all — which on this surface is the normal case, not the
/// exception.
void main() {
  /// A 1x1 transparent PNG. Real bytes, so `Image.memory` actually decodes.
  final Uint8List png = Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  group('what the kitchen keeps', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    KdsDishPhotos notifier() => container.read(kdsDishPhotosProvider.notifier);

    test('a board frame adds its photographs', () {
      notifier().absorb(<String, String>{'p-1': 'https://cdn/a.webp'});
      expect(container.read(kdsDishPhotosProvider), hasLength(1));
    });

    test('a later frame MERGES — it never forgets a ticket on screen', () {
      notifier().absorb(<String, String>{'p-1': 'https://cdn/a.webp'});
      notifier().absorb(<String, String>{'p-2': 'https://cdn/b.webp'});

      // ⚠ The defect this prevents: a frame carries the dishes on the board
      // *now*, so a replace would blank the picture of a card a cook is
      // reading the moment any other ticket changes.
      expect(container.read(kdsDishPhotosProvider).keys, <String>{
        'p-1',
        'p-2',
      });
    });

    test('an empty frame changes nothing at all', () {
      notifier().absorb(<String, String>{'p-1': 'https://cdn/a.webp'});
      final Map<String, String> before = container.read(kdsDishPhotosProvider);
      notifier().absorb(const <String, String>{});
      expect(container.read(kdsDishPhotosProvider), same(before));
    });

    test('a repeated frame does not churn the state', () {
      notifier().absorb(<String, String>{'p-1': 'https://cdn/a.webp'});
      final Map<String, String> before = container.read(kdsDishPhotosProvider);
      notifier().absorb(<String, String>{'p-1': 'https://cdn/a.webp'});
      // A board frame arrives every few seconds; rebuilding every card each
      // time for an identical map is work a kitchen tablet cannot spare.
      expect(container.read(kdsDishPhotosProvider), same(before));
    });

    test('it is bounded — a long service cannot grow it forever', () {
      for (int i = 0; i < 260; i++) {
        notifier().absorb(<String, String>{'p-$i': 'https://cdn/$i.webp'});
      }
      final Map<String, String> photos = container.read(kdsDishPhotosProvider);
      expect(photos.length, lessThanOrEqualTo(200));
      // The most recent survive: those are the dishes on the board.
      expect(photos.containsKey('p-259'), isTrue);
      expect(photos.containsKey('p-0'), isFalse);
    });
  });

  group('the cache is what makes it work with no internet', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kds-photos-test');
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    test(
      'a photograph fetched before the outage is read off the disk',
      () async {
        // ⚠ This is the whole point of caching on this surface. The kitchen is
        // the one screen that must keep working when the router loses the
        // internet; the picture was fetched while there was a connection.
        final CachingPhotoStore warm = CachingPhotoStore(
          directoryOverride: dir,
        );
        const String url = 'https://cdn.timmaeats.com/catalog/ndole.webp';

        // Seed the cache the way a successful fetch would have.
        final CachingPhotoStore seeder = CachingPhotoStore(
          directoryOverride: dir,
        );
        await seeder.seedForTest(url, png);

        expect(await warm.load(url), png);
        expect(
          warm.fetchAttempts,
          0,
          reason: 'a cached photograph must not touch the network',
        );
      },
    );

    test(
      'a URL that cannot be fetched is tried ONCE, not every frame',
      () async {
        final CachingPhotoStore store = CachingPhotoStore(
          directoryOverride: dir,
        );
        // Nothing is listening here, and nothing should be.
        const String dead = 'http://127.0.0.1:9/never.webp';

        expect(await store.load(dead), isNull);
        expect(await store.load(dead), isNull);
        expect(await store.load(dead), isNull);

        // ⚠ Without the backoff this is one request per missing photograph per
        // board frame — every five seconds, from a kitchen, for ever.
        expect(store.fetchAttempts, 1);
      },
    );

    test('a non-http URL is refused without a request', () async {
      final CachingPhotoStore store = CachingPhotoStore(directoryOverride: dir);
      for (final String bad in <String>[
        'file:///etc/passwd',
        'data:image/png;base64,AAAA',
        'not a url at all',
      ]) {
        expect(await store.load(bad), isNull, reason: bad);
      }
      expect(store.fetchAttempts, 0);
    });
  });

  group('the thumbnail on a ticket line', () {
    Widget host(ProviderContainer container, String productId) =>
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: KdsDishPhoto(
                  productId: productId,
                  side: KdsScale.thumbSide,
                ),
              ),
            ),
          ),
        );

    testWidgets('holds its exact space before the picture arrives', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [kdsPhotoStoreProvider.overrideWithValue(_SlowStore())],
      );
      addTearDown(container.dispose);
      container.read(kdsDishPhotosProvider.notifier).absorb(<String, String>{
        'p-1': 'https://cdn/a.webp',
      });

      await tester.pumpWidget(host(container, 'p-1'));

      // ⚠ **The reflow is the defect.** The board re-reads every five seconds;
      // a thumbnail that only takes space once its bytes land would shift
      // every line under it while a cook is reading the card.
      expect(
        tester.getSize(find.byType(KdsDishPhoto)),
        const Size(KdsScale.thumbSide, KdsScale.thumbSide),
      );
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('draws the dish once the bytes are in', (tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [kdsPhotoStoreProvider.overrideWithValue(_FakeStore(png))],
      );
      addTearDown(container.dispose);
      container.read(kdsDishPhotosProvider.notifier).absorb(<String, String>{
        'p-1': 'https://cdn/a.webp',
      });

      await tester.pumpWidget(host(container, 'p-1'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsNothing);
      // Same footprint as the placeholder: nothing moved when it arrived.
      expect(
        tester.getSize(find.byType(KdsDishPhoto)),
        const Size(KdsScale.thumbSide, KdsScale.thumbSide),
      );
    });

    testWidgets('a dish with no photograph still occupies the slot', (
      tester,
    ) async {
      final _FakeStore store = _FakeStore(png);
      final ProviderContainer container = ProviderContainer(
        overrides: [kdsPhotoStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(host(container, 'p-unknown'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(
        tester.getSize(find.byType(KdsDishPhoto)),
        const Size(KdsScale.thumbSide, KdsScale.thumbSide),
      );
      expect(
        store.asked,
        isEmpty,
        reason: 'nothing to fetch, so nothing is fetched',
      );
    });

    testWidgets('a line whose dish was deleted asks for nothing', (
      tester,
    ) async {
      // `order_items.product_id` is `on delete set null`: a dish deleted in
      // the dashboard leaves live lines with an empty id.
      final _FakeStore store = _FakeStore(png);
      final ProviderContainer container = ProviderContainer(
        overrides: [kdsPhotoStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(host(container, ''));
      await tester.pumpAndSettle();

      expect(store.asked, isEmpty);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('one request per dish, however often the board redraws', (
      tester,
    ) async {
      final _FakeStore store = _FakeStore(png);
      final ProviderContainer container = ProviderContainer(
        overrides: [kdsPhotoStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.read(kdsDishPhotosProvider.notifier).absorb(<String, String>{
        'p-1': 'https://cdn/a.webp',
      });

      await tester.pumpWidget(host(container, 'p-1'));
      await tester.pumpAndSettle();
      for (int i = 0; i < 5; i++) {
        // What the five-second board re-read does to this widget.
        await tester.pumpWidget(host(container, 'p-1'));
        await tester.pumpAndSettle();
      }

      expect(store.asked, <String>['https://cdn/a.webp']);
    });
  });
}

class _FakeStore implements KdsPhotoStore {
  _FakeStore(this.bytes);

  final Uint8List bytes;
  final List<String> asked = <String>[];

  @override
  Future<Uint8List?> load(String url) async {
    asked.add(url);
    return bytes;
  }
}

/// Never answers — the moment between a board frame and a photograph.
class _SlowStore implements KdsPhotoStore {
  @override
  Future<Uint8List?> load(String url) => Completer<Uint8List?>().future;
}
