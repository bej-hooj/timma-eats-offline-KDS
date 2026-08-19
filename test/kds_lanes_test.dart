import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/kds/domain/kds_lanes.dart';

/// K5 — lane logic, **ported from the web board's `KdsColumn` / `KdsLanesTest`**
/// so the two KDS implementations cannot drift.
///
/// Two screens showing one kitchen is the drift risk this file exists to hold
/// shut: if these expectations ever stop matching
/// `timmaeat-webapp/app/Services/Orders/Admin/KdsColumn.php`, the same ticket
/// behaves differently depending on which board a cook is standing at.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 16, 12);

  PosOrder order({
    required String status,
    String mode = PosOrderMode.pickup,
    String paymentStatus = PosPaymentStatus.unpaid,
    DateTime? placedAt,
    String clientId = 'c1',
  }) => PosOrder(
    clientId: clientId,
    branchId: 'b1',
    origin: PosOrderOrigin.local,
    source: PosOrderSource.kiosk,
    mode: mode,
    status: status,
    paymentStatus: paymentStatus,
    paymentMethod: PosPaymentMethod.payAtCounter,
    deviceSeq: 1,
    subtotal: 3500,
    discount: 0,
    deliveryFee: 0,
    total: 3500,
    placedAtDevice: placedAt ?? now,
    statusChangedAt: placedAt ?? now,
  );

  group('advanceFor is keyed on STATUS, never on the lane', () {
    test('the whole forward path matches the web board', () {
      expect(
        KdsLane.advanceFor(PosOrderStatus.placed, PosOrderMode.pickup),
        PosOrderStatus.accepted,
      );
      expect(
        KdsLane.advanceFor(PosOrderStatus.accepted, PosOrderMode.pickup),
        PosOrderStatus.preparing,
      );
      expect(
        KdsLane.advanceFor(PosOrderStatus.preparing, PosOrderMode.pickup),
        PosOrderStatus.ready,
      );
    });

    test('an accepted card drawn in the Preparing lane still advances to '
        'preparing — bug B1', () {
      // The board draws `accepted` in the Preparing lane. A lane-keyed map
      // offered those cards `preparing → ready`, which the state machine
      // refuses as bad_transition — permanently, because the status never
      // changed and a refresh could not help. The whole board was stuck.
      final PosOrder accepted = order(status: PosOrderStatus.accepted);
      expect(KdsLane.laneFor(accepted), KdsLane.preparing);
      expect(
        KdsLane.advanceFor(accepted.status, accepted.mode),
        PosOrderStatus.preparing,
        reason:
            'a lane is a presentation choice; a transition is a '
            'state-machine fact',
      );
    });

    test('mode decides only the last hop', () {
      expect(
        KdsLane.advanceFor(PosOrderStatus.ready, PosOrderMode.delivery),
        PosOrderStatus.outForDelivery,
      );
      expect(
        KdsLane.advanceFor(PosOrderStatus.ready, PosOrderMode.pickup),
        PosOrderStatus.completed,
      );
      expect(
        KdsLane.advanceFor(PosOrderStatus.ready, PosOrderMode.dineIn),
        PosOrderStatus.completed,
      );
      expect(
        KdsLane.advanceFor(
          PosOrderStatus.outForDelivery,
          PosOrderMode.delivery,
        ),
        PosOrderStatus.completed,
      );
    });

    test('an unpaid ticket has no advance at all — it gets settled', () {
      expect(
        KdsLane.advanceFor(PosOrderStatus.pendingPayment, PosOrderMode.pickup),
        isNull,
        reason:
            'offering a cook an advance on an unpaid ticket is how food '
            'leaves the building without being paid for',
      );
    });

    test('terminal statuses offer nothing', () {
      for (final String status in PosOrderStatus.terminal) {
        expect(KdsLane.advanceFor(status, PosOrderMode.pickup), isNull);
      }
    });

    test('every advance the board offers is one the state machine allows', () {
      // The real guarantee: the board can never offer a transition that
      // `StatusGuard` will refuse. This is the assertion that would have caught
      // bug B1 before it reached a kitchen.
      for (final String status in PosOrderStatus.all) {
        for (final String mode in <String>[
          PosOrderMode.pickup,
          PosOrderMode.delivery,
          PosOrderMode.dineIn,
        ]) {
          final String? to = KdsLane.advanceFor(status, mode);
          if (to == null) {
            continue;
          }
          expect(
            StatusGuard.allows(from: status, to: to, mode: mode),
            isTrue,
            reason:
                '$status → $to (mode $mode) is offered by the board but '
                'refused by the guard',
          );
        }
      }
    });
  });

  group('lanes', () {
    test('an unpaid kiosk ticket sits in the counter lane', () {
      expect(
        KdsLane.laneFor(order(status: PosOrderStatus.pendingPayment)),
        KdsLane.counter,
        reason: 'the counter lane is what releases tickets to the kitchen',
      );
    });

    test('accepted and preparing share one lane', () {
      expect(
        KdsLane.laneFor(order(status: PosOrderStatus.accepted)),
        KdsLane.preparing,
      );
      expect(
        KdsLane.laneFor(order(status: PosOrderStatus.preparing)),
        KdsLane.preparing,
      );
    });

    test('terminal tickets leave the board', () {
      for (final String status in PosOrderStatus.terminal) {
        expect(KdsLane.laneFor(order(status: status)), isNull);
      }
    });

    test('the board buckets every open ticket and keeps empty lanes', () {
      final Map<String, List<PosOrder>> board = KdsLane.board(<PosOrder>[
        order(status: PosOrderStatus.pendingPayment, clientId: 'a'),
        order(status: PosOrderStatus.placed, clientId: 'b'),
        order(status: PosOrderStatus.accepted, clientId: 'c'),
        order(status: PosOrderStatus.preparing, clientId: 'd'),
        order(status: PosOrderStatus.completed, clientId: 'e'),
      ], now: now);
      expect(board.keys, containsAll(KdsLane.all));
      expect(board[KdsLane.counter], hasLength(1));
      expect(board[KdsLane.newTickets], hasLength(1));
      expect(board[KdsLane.preparing], hasLength(2));
      expect(board[KdsLane.ready], isEmpty);
      expect(
        board.values.expand((List<PosOrder> l) => l),
        hasLength(4),
        reason: 'the completed ticket left the board',
      );
    });

    test('oldest first — the ticket that waited longest is the one owed', () {
      final Map<String, List<PosOrder>> board = KdsLane.board(<PosOrder>[
        order(
          status: PosOrderStatus.placed,
          clientId: 'newer',
          placedAt: now.subtract(const Duration(minutes: 2)),
        ),
        order(
          status: PosOrderStatus.placed,
          clientId: 'older',
          placedAt: now.subtract(const Duration(minutes: 20)),
        ),
      ], now: now);
      expect(
        board[KdsLane.newTickets]!.map((PosOrder o) => o.clientId),
        <String>['older', 'newer'],
      );
    });
  });

  group('SLA thresholds match config/kds.php', () {
    test('amber at 10 minutes, red at 20', () {
      expect(KdsSla.amberAfter, const Duration(minutes: 10));
      expect(KdsSla.redAfter, const Duration(minutes: 20));
      expect(KdsSla.reminderEvery, const Duration(seconds: 60));
    });

    test('a card ages calm → amber → red', () {
      PosOrder aged(int minutes) => order(
        status: PosOrderStatus.placed,
        placedAt: now.subtract(Duration(minutes: minutes)),
      );
      expect(KdsSla.urgencyOf(aged(0), now), KdsUrgency.calm);
      expect(KdsSla.urgencyOf(aged(9), now), KdsUrgency.calm);
      expect(KdsSla.urgencyOf(aged(10), now), KdsUrgency.amber);
      expect(KdsSla.urgencyOf(aged(19), now), KdsUrgency.amber);
      expect(KdsSla.urgencyOf(aged(20), now), KdsUrgency.red);
    });
  });
}
