import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pos_core/pos_core.dart';
import 'package:pos_link/pos_link.dart';

import 'package:timma_kds/kds/domain/kds_lanes.dart';

/// A kitchen board on the command line: pairs with a real kiosk hub and prints
/// every board it receives.
///
/// **Why this exists.** The board runs on an iPhone, and Apple gives no way to
/// inject taps into a device outside a test harness — so the end-to-end
/// question "does an order placed on the kiosk reach the kitchen over the shop
/// wifi?" could only be answered by a human holding two handsets. This is the
/// same question, answerable from a terminal, using the **production**
/// `LanPairingClient` and `LanSocketTransport`: the only thing it does not
/// exercise is the board's own Flutter UI.
///
///     dart run tool/board_probe.dart <host> <port> <six-digit code> [--advance]
///
/// With `--advance` it does not just watch: it takes cash on the first unpaid
/// ticket it sees and then walks it forward one step, which is the **return**
/// leg — the cook's tap travelling back to the kiosk. That leg is the half a
/// screenshot of the board cannot show, and the half that was missing entirely
/// until the link controller drained the outbox.
///
/// Nothing here is a test double. It pairs for real, is approved by the same
/// registry, holds a real credential and reads the same signed frames the
/// iPhone would.
Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      'usage: dart run tool/board_probe.dart <host> <port> <code>',
    );
    exitCode = 64;
    return;
  }
  final String host = args[0];
  final int port = int.tryParse(args[1]) ?? 8801;
  final String code = args[2];
  final bool advance = args.contains('--advance');

  // Which restaurant is this kiosk? The board must know before it pairs, and
  // `/health` is where a hand-paired board learns it.
  final Map<String, dynamic> health = await _health(host, port);
  final String branchId = health['branch_id'] as String;
  stdout.writeln('hub    : ${health['hub_label']} ($branchId)');

  final PosStore store = SqlitePosStore.inMemory();
  final PosDeviceIdentity identity = PosDeviceIdentity(
    deviceId: PosIds.newDeviceId(),
    branchId: branchId,
    role: PosDeviceRole.kds,
    label: 'Sonde cuisine',
  );
  store.writeIdentity(identity);

  stdout.writeln('pairing: ${identity.deviceId}');
  final PairingResult pairing = await LanPairingClient.pair(
    endpoint: HubEndpoint(host: host, port: port),
    identity: identity,
    code: code,
  );
  stdout.writeln(
    'paired : hub=${pairing.hubDeviceId} label=${pairing.hubLabel}',
  );
  stdout.writeln(
    'secret : ${pairing.collectionSecret.bytes.length} bytes received',
  );

  // A real engine on the probe's own store, so what arrives is merged exactly
  // as the iPhone would merge it — and so the outbox this drains is the same
  // outbox a cook's tap fills.
  final PosEngine engine = PosEngine(store: store, identity: identity);
  OutboxDrain? drain;
  final Set<String> acted = <String>{};

  // Declared before the transport that closes over it: the snapshot callback is
  // built as part of the transport's own constructor, so it cannot name the
  // transport directly.
  late final LanSocketTransport link;

  int boards = 0;
  link = LanSocketTransport(
    endpoint: HubEndpoint(host: host, port: port),
    identity: identity,
    credential: pairing.credential,
    onSnapshot: (BoardSnapshot snapshot) async {
      boards++;
      snapshot.applyTo(engine);
      final DateTime now = DateTime.now();
      stdout.writeln(
        '[${now.toIso8601String()}] board #$boards — '
        '${snapshot.orders.length} commande(s)',
      );
      // ⚠ A snapshot carries `orders` of `BoardOrder`, each wrapping a
      // `PosOrder` and its lines — there is no `BoardTicket`. A ticket number
      // is one field on the order, not the thing the wire is made of, and
      // guessing otherwise is what stopped this file compiling.
      for (final BoardOrder entry in snapshot.orders) {
        final PosOrder order = entry.order;
        stdout.writeln(
          '   • #${order.ticketNumber ?? '-'}  ${order.status}  '
          '${order.total} XAF  (${entry.lines.length} ligne(s))',
        );
      }

      if (!advance) {
        return;
      }
      // One action per ticket, once. A probe that re-advanced on every board it
      // received would race the kiosk's own broadcasts and look like a bug in
      // the transport rather than in the probe.
      for (final BoardOrder entry in snapshot.orders) {
        final PosOrder order = entry.order;
        if (acted.contains(order.clientId)) {
          continue;
        }
        try {
          if (order.status == PosOrderStatus.pendingPayment) {
            engine.settleCounterCash(order.clientId);
            stdout.writeln('   → encaissé #${order.ticketNumber ?? '-'}');
          } else {
            final String? to = KdsLane.advanceFor(order.status, order.mode);
            if (to == null) {
              continue;
            }
            engine.advance(order.clientId, to);
            stdout.writeln('   → #${order.ticketNumber ?? '-'} → $to');
          }
          acted.add(order.clientId);
        } on PosError catch (error) {
          stdout.writeln('   ! refusé: ${error.code}');
        }
      }
      final DrainReport report = await (drain ??= OutboxDrain(
        store: store,
        sink: link,
      )).drainOnce();
      if (report.delivered > 0) {
        stdout.writeln('   ↑ ${report.delivered} intention(s) envoyée(s)');
      }
    },
  );

  await link.connect();
  stdout.writeln('linked : waiting for orders — place one on the kiosk now');
  stdout.writeln('         (Ctrl-C to stop)');

  // Stay up so the hub's broadcasts arrive. A board is a screen somebody is
  // watching; this is the same, without the screen.
  await ProcessSignal.sigint.watch().first;
  await link.close();
  store.close();
  stdout.writeln('stopped after $boards board update(s)');
}

Future<Map<String, dynamic>> _health(String host, int port) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);
  try {
    final HttpClientRequest request = await client.getUrl(
      Uri.parse('http://$host:$port/health'),
    );
    final HttpClientResponse response = await request.close();
    final String body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}
