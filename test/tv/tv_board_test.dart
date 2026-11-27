import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/tv/domain/tv_board.dart';
import 'package:timma_kds/tv/domain/tv_rules.dart';
import 'package:timma_kds/tv/domain/tv_ticket.dart';

import 'tv_fixtures.dart';

void main() {
  TvBoard project(List<PosOrder> orders, {DateTime? now, Map<String, List<PosOrderLine>> lines = const {}}) =>
      TvBoard.project(
        orders: orders,
        linesOf: (String id) => lines[id] ?? const <PosOrderLine>[],
        now: now ?? t0,
      );

  test('only kiosk orders reach the TV', () {
    final TvBoard b = project(<PosOrder>[
      order('k', number: 1),
      order('a', source: PosOrderSource.app, number: 2),
      order('w', source: PosOrderSource.web, number: 3),
    ]);
    expect(b.preparing.map((TvTicket t) => t.clientId), <String>['k']);
  });

  test('placed, accepted and preparing are « En préparation »', () {
    final TvBoard b = project(<PosOrder>[
      order('p', status: PosOrderStatus.placed),
      order('a', status: PosOrderStatus.accepted),
      order('c', status: PosOrderStatus.preparing),
      order('u', status: PosOrderStatus.pendingPayment),
    ]);
    expect(b.preparing.map((TvTicket t) => t.clientId).toSet(), <String>{'p', 'a', 'c'});
    expect(b.ready, isEmpty);
  });

  test('a ready ticket stays 3 minutes, not one second more', () {
    final PosOrder r = order('r', status: PosOrderStatus.ready, changed: t0);
    expect(project(<PosOrder>[r], now: t0.add(const Duration(minutes: 2, seconds: 59))).ready, hasLength(1));
    expect(project(<PosOrder>[r], now: t0.add(TvRules.readyVisibleFor)).ready, isEmpty);
  });

  test('completed or cancelled orders are not shown', () {
    final TvBoard b = project(<PosOrder>[
      order('d', status: PosOrderStatus.completed),
      order('x', status: PosOrderStatus.cancelled),
    ]);
    expect(b.preparing, isEmpty);
    expect(b.ready, isEmpty);
  });

  test('preparing oldest first, ready newest first', () {
    final TvBoard b = project(<PosOrder>[
      order('p2', placed: t0.add(const Duration(minutes: 2))),
      order('p1', placed: t0),
      order('r1', status: PosOrderStatus.ready, changed: t0),
      order('r2', status: PosOrderStatus.ready, changed: t0.add(const Duration(seconds: 30))),
    ], now: t0.add(const Duration(minutes: 1)));
    expect(b.preparing.map((TvTicket t) => t.clientId), <String>['p1', 'p2']);
    expect(b.ready.map((TvTicket t) => t.clientId), <String>['r2', 'r1']);
  });

  test('overflow keeps the newest ready tickets', () {
    final List<PosOrder> many = <PosOrder>[
      for (int i = 0; i < TvRules.maxPerColumn + 3; i++)
        order('r$i', status: PosOrderStatus.ready, changed: t0.add(Duration(seconds: i))),
    ];
    final TvBoard b = project(many, now: t0.add(const Duration(minutes: 1)));
    expect(b.ready, hasLength(TvRules.maxPerColumn));
    expect(b.ready.first.clientId, 'r${TvRules.maxPerColumn + 2}');
    expect(b.ready.map((TvTicket t) => t.clientId), isNot(contains('r0')));
  });

  test('a ticket without a number is skipped; dailyCode is a fallback label', () {
    final TvBoard b = project(<PosOrder>[
      order('blank', number: null),
      order('daily', number: null, dailyCode: 'K12'),
    ]);
    expect(b.preparing.map((TvTicket t) => t.label), <String>['K12']);
  });

  test('ready tickets carry their lines with the variant', () {
    final TvBoard b = project(
      <PosOrder>[order('r', status: PosOrderStatus.ready)],
      lines: <String, List<PosOrderLine>>{
        'r': <PosOrderLine>[line('Ndolé', 2), line('Jus', 1, variant: 'gingembre')],
      },
    );
    expect(b.ready.single.lines, const <TvSpokenLine>[
      TvSpokenLine(quantity: 2, name: 'Ndolé'),
      TvSpokenLine(quantity: 1, name: 'Jus gingembre'),
    ]);
  });

  test('highlight lasts 10 seconds after ready', () {
    final TvTicket t = project(<PosOrder>[order('r', status: PosOrderStatus.ready)]).ready.single;
    expect(TvBoard.isHighlighted(t, t0.add(const Duration(seconds: 9))), isTrue);
    expect(TvBoard.isHighlighted(t, t0.add(const Duration(seconds: 11))), isFalse);
  });
}
