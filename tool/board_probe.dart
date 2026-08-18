import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pos_core/pos_core.dart';
import 'package:pos_link/pos_link.dart';

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
///     dart run tool/board_probe.dart <host> <port> <six-digit code>
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
  stdout.writeln('paired : hub=${pairing.hubDeviceId} label=${pairing.hubLabel}');
  stdout.writeln(
    'secret : ${pairing.collectionSecret.bytes.length} bytes received',
  );

  int boards = 0;
  final LanSocketTransport transport = LanSocketTransport(
    endpoint: HubEndpoint(host: host, port: port),
    identity: identity,
    credential: pairing.credential,
    onSnapshot: (BoardSnapshot snapshot) {
      boards++;
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
    },
  );

  await transport.connect();
  stdout.writeln('linked : waiting for orders — place one on the kiosk now');
  stdout.writeln('         (Ctrl-C to stop)');

  // Stay up so the hub's broadcasts arrive. A board is a screen somebody is
  // watching; this is the same, without the screen.
  await ProcessSignal.sigint.watch().first;
  await transport.close();
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
