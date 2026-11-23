import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_link/pos_link.dart';

import 'package:timma_kds/design/app_tokens.dart';
import '../theme/kds_scale.dart';

/// The dish photographs the kitchen knows about, `product_id` → URL.
///
/// Owner, 2026-11-23: *"i want the kitchen dish on the kitchen pipeline to have
/// dishes images. Of cause they are data-driven from the dashboard (database)
/// when the kitchen is connected to the internet"*.
///
/// They arrive on the board frame, resolved by the borne from its active menu
/// bundle — so they are the dashboard's own photographs with no second source
/// (see [BoardSnapshot.photos]). This notifier is where they live on the
/// kitchen side; it is deliberately **not** in the store, because a photograph
/// is live content and not part of what a ticket snapshotted.
class KdsDishPhotos extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const <String, String>{};

  /// ⚠ **Merges, never replaces.** A board frame carries the dishes on the
  /// board right now; a kitchen that dropped everything else would lose the
  /// picture of a ticket still on screen the moment a frame arrives without
  /// it. Bounded so a long service cannot grow it without limit.
  void absorb(Map<String, String> arrived) {
    if (arrived.isEmpty) {
      return;
    }
    final Map<String, String> next = <String, String>{...state, ...arrived};
    if (next.length > _cap) {
      // Oldest first: a `Map` keeps insertion order, and the dishes that
      // arrived most recently are the ones on the board.
      final List<String> keys = next.keys.toList();
      for (final String key in keys.take(next.length - _cap)) {
        next.remove(key);
      }
    }
    if (!mapEquals(next, state)) {
      state = next;
    }
  }

  static const int _cap = 200;
}

final NotifierProvider<KdsDishPhotos, Map<String, String>>
kdsDishPhotosProvider = NotifierProvider<KdsDishPhotos, Map<String, String>>(
  KdsDishPhotos.new,
);

/// Fetches a photograph once and keeps it.
///
/// Behind an interface for the usual reason: the real one talks to a network
/// and a disk, and a board that can only be exercised with both is a board
/// nobody checks again.
abstract interface class KdsPhotoStore {
  /// The bytes, or null when there are none to be had. Never throws.
  Future<Uint8List?> load(String url);
}

/// Disk-backed, with an in-memory layer in front.
///
/// ⚠ **The in-memory layer is not an optimisation.** The board re-reads every
/// five seconds and rebuilds every card; without it each rebuild would hit the
/// filesystem for every line on screen, on a tablet, forever.
///
/// ⚠ **The disk layer is the whole point of caching at all.** The kitchen is
/// the surface that must keep working when the router loses the internet — the
/// photographs are fetched while there is a connection and read from disk
/// after it goes, which is what "data-driven when the kitchen is connected"
/// has to mean on a board that outlives the connection.
class CachingPhotoStore implements KdsPhotoStore {
  CachingPhotoStore({HttpClient? client, this.directoryOverride})
    : _client = client ?? (HttpClient()..connectionTimeout = _timeout);

  /// A directory a test hands in, so the disk layer can be exercised without
  /// a platform channel. Null in the app, where the platform's support
  /// directory is resolved on the first lookup.
  @visibleForTesting
  final Directory? directoryOverride;

  /// Where the bytes are kept between services. Null until the first lookup
  /// resolves the platform's support directory, which is why it is not an
  /// initialising formal.
  Directory? _directory;

  static const Duration _timeout = Duration(seconds: 8);

  /// Beyond this a "photograph" is something else, and a kitchen tablet should
  /// not be made to decode it. The dashboard caps uploads at 1200 px.
  static const int _maxBytes = 3 * 1024 * 1024;

  final HttpClient _client;

  final Map<String, Uint8List> _memory = <String, Uint8List>{};
  final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};

  /// A URL that failed is not retried on every board frame — that is a request
  /// every five seconds per missing photograph, from a kitchen, for ever.
  final Map<String, DateTime> _failedAt = <String, DateTime>{};
  static const Duration _retryAfter = Duration(minutes: 10);

  /// How many times this store has actually reached for the network. Exposed
  /// because the rules worth checking here — one fetch per URL, no retry
  /// storm, a cached file instead of a request — are all statements about
  /// attempts, and a rule that can only be checked by watching a router is a
  /// rule nobody checks.
  @visibleForTesting
  int fetchAttempts = 0;

  @override
  Future<Uint8List?> load(String url) {
    final Uint8List? known = _memory[url];
    if (known != null) {
      return Future<Uint8List?>.value(known);
    }
    final DateTime? failed = _failedAt[url];
    if (failed != null && DateTime.now().difference(failed) < _retryAfter) {
      return Future<Uint8List?>.value();
    }
    // One fetch per URL however many cards ask at once: a board with six
    // tickets of the same dish must not open six connections.
    return _inFlight[url] ??= _load(url).whenComplete(() {
      _inFlight.remove(url);
    });
  }

  Future<Uint8List?> _load(String url) async {
    final File? file = await _fileFor(url);
    if (file != null && file.existsSync()) {
      try {
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _memory[url] = bytes;
          return bytes;
        }
      } on Object catch (error) {
        debugPrint('[KdsPhotos] cached file unreadable: $error');
      }
    }

    final Uint8List? fetched = await _fetch(url);
    if (fetched == null) {
      _failedAt[url] = DateTime.now();
      return null;
    }
    _memory[url] = fetched;
    if (file != null) {
      // Best effort: a kitchen with a full disk still shows the picture it
      // just fetched.
      try {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(fetched, flush: false);
      } on Object catch (error) {
        debugPrint('[KdsPhotos] could not cache: $error');
      }
    }
    return fetched;
  }

  Future<Uint8List?> _fetch(String url) async {
    // ⚠ Re-checked here even though the decoder already did it
    // ([BoardSnapshot.photos]). This class is reachable from anywhere in the
    // app and "the caller validated it" is the assumption that ends with a
    // kitchen reading its own disk because of a frame.
    final Uri? uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    fetchAttempts++;
    try {
      final HttpClientRequest request = await _client
          .getUrl(uri)
          .timeout(_timeout);
      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }
      final List<int> bytes = <int>[];
      await for (final List<int> chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) {
          return null;
        }
      }
      return bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } on Object catch (error) {
      // Offline is the normal case here, not an exception worth shouting
      // about: the board goes on showing names.
      debugPrint('[KdsPhotos] $url: ${error.runtimeType}');
      return null;
    }
  }

  /// Writes [bytes] into the disk layer as a successful fetch would have.
  ///
  /// The outage case cannot be reached any other way: a test that first fetched
  /// over the network to warm the cache would be a test with a network in it.
  @visibleForTesting
  Future<void> seedForTest(String url, Uint8List bytes) async {
    final File? file = await _fileFor(url);
    if (file == null) {
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<File?> _fileFor(String url) async {
    try {
      final Directory base = _directory ??=
          directoryOverride ??
          Directory(
            '${(await getApplicationSupportDirectory()).path}/dish-photos',
          );
      // ⚠ The file name is a HASH of the URL, never the URL. A path built
      // from remote text is a path-traversal waiting to happen, and a CDN URL
      // is longer than some filesystems allow anyway.
      final String name = sha256.convert(utf8.encode(url)).toString();
      return File('${base.path}/$name');
    } on Object catch (error) {
      debugPrint('[KdsPhotos] no cache directory: $error');
      return null;
    }
  }
}

/// The real store. Overridden in tests, which is why the default is the one
/// that works rather than a stub — a seam whose default is a stub ships blank.
final Provider<KdsPhotoStore> kdsPhotoStoreProvider = Provider<KdsPhotoStore>(
  (Ref ref) => CachingPhotoStore(),
);

/// A dish photograph on a kitchen ticket.
///
/// ⚠ **It occupies its space whether or not there is a picture.** The board
/// re-reads every five seconds; a thumbnail that appeared when its bytes
/// arrived would re-flow every line under it while a cook is reading the card,
/// which is worse than no picture at all. So the slot is always [side] wide
/// and shows, in order: the photograph, or a dish glyph while it is coming or
/// if it never does.
///
/// ⚠ **The quantity stays the loudest thing on the line.** A picture helps a
/// cook find the dish; the number is what they have to get right.
class KdsDishPhoto extends ConsumerStatefulWidget {
  const KdsDishPhoto({required this.productId, required this.side, super.key});

  final String productId;
  final double side;

  @override
  ConsumerState<KdsDishPhoto> createState() => _KdsDishPhotoState();
}

class _KdsDishPhotoState extends ConsumerState<KdsDishPhoto> {
  Uint8List? _bytes;
  String? _loadedUrl;

  void _resolve(String? url) {
    if (url == null || url == _loadedUrl) {
      return;
    }
    _loadedUrl = url;
    final KdsPhotoStore store = ref.read(kdsPhotoStoreProvider);
    unawaited(
      store.load(url).then((Uint8List? bytes) {
        // The card can leave the board between the request and the answer —
        // a cook taps *Prêt* and the ticket goes.
        if (!mounted || _loadedUrl != url) {
          return;
        }
        setState(() => _bytes = bytes);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? url = widget.productId.isEmpty
        ? null
        : ref.watch(kdsDishPhotosProvider)[widget.productId];
    _resolve(url);

    final Uint8List? bytes = _bytes;
    return SizedBox(
      width: widget.side,
      height: widget.side,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(KdsScale.radiusSmall),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KdsScale.radiusSmall),
          child: bytes == null
              ? Center(
                  child: Icon(
                    Icons.restaurant,
                    size: widget.side * 0.5,
                    color: AppColors.textMuted,
                  ),
                )
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: widget.side,
                  height: widget.side,
                  // ⚠ Decoded at the size it is DRAWN at, times the device
                  // ratio. A 1200 px dashboard upload decoded at full size for
                  // a 56 dp slot is about 50x the pixels, held per line, on a
                  // board that may show thirty lines — that is how a kitchen
                  // tablet runs out of memory halfway through a service.
                  cacheWidth:
                      (widget.side * MediaQuery.devicePixelRatioOf(context) * 2)
                          .round(),
                  gaplessPlayback: true,
                  // A corrupt cached file must not take the board down.
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.restaurant,
                      size: widget.side * 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
