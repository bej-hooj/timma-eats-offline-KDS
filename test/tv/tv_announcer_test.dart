import 'package:flutter_test/flutter_test.dart';
import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/tv/domain/tv_announcer.dart';
import 'package:timma_kds/tv/domain/tv_board.dart';
import 'package:timma_kds/tv/domain/tv_rules.dart';
import 'package:timma_kds/tv/domain/tv_utterance.dart';

import 'tv_fixtures.dart';

void main() {
  late TvAnnouncer announcer;
  setUp(() => announcer = TvAnnouncer(phrases: frPhrases));

  TvBoard board(List<PosOrder> orders, DateTime now) => TvBoard.project(
    orders: orders,
    linesOf: (String id) => <PosOrderLine>[line('Ndolé', 2)],
    now: now,
  );

  List<TvUtterance> step(List<PosOrder> orders, DateTime now) =>
      announcer.next(board(orders, now), now);

  test('the first board after launch is silent', () {
    expect(step(<PosOrder>[order('a'), order('b', status: PosOrderStatus.ready)], t0), isEmpty);
  });

  test('a new ticket is announced once, then silence on re-reads', () {
    step(const <PosOrder>[], t0);
    final List<TvUtterance> first = step(<PosOrder>[order('a', number: 7)], t0);
    expect(first.single.text, 'Commande 0. 7. en préparation.');
    expect(first.single.priority, TvUtterancePriority.preparing);
    expect(first.single.chime, isFalse);
    expect(step(<PosOrder>[order('a', number: 7)], t0.add(const Duration(seconds: 2))), isEmpty);
  });

  test('ready: chime + sentence with the dishes, once', () {
    step(<PosOrder>[order('a', number: 7)], t0);
    final DateTime t1 = t0.add(const Duration(minutes: 5));
    final List<PosOrder> ready = <PosOrder>[order('a', number: 7, status: PosOrderStatus.ready, changed: t1)];
    final List<TvUtterance> said = step(ready, t1);
    expect(said.single.text, 'Commande 0. 7. est prête. 2 Ndolé. Je répète : 0. 7.');
    expect(said.single.chime, isTrue);
    expect(step(ready, t1.add(const Duration(seconds: 2))), isEmpty);
  });

  test('a ticket that skipped « en préparation » is still announced ready', () {
    step(const <PosOrder>[], t0);
    expect(step(<PosOrder>[order('a', status: PosOrderStatus.ready)], t0).single.priority, TvUtterancePriority.ready);
  });

  test('rotation: every 30 s, round-robin over the ready tickets', () {
    step(const <PosOrder>[], t0);
    final List<PosOrder> ready = <PosOrder>[
      order('a', number: 1, status: PosOrderStatus.ready, changed: t0),
      order('b', number: 2, status: PosOrderStatus.ready, changed: t0.add(const Duration(seconds: 1))),
    ];
    expect(step(ready, t0.add(const Duration(seconds: 1))), hasLength(2));
    expect(step(ready, t0.add(const Duration(seconds: 20))), isEmpty);
    final List<String> rotated = <String>[
      for (int i = 1; i <= 3; i++)
        ...step(ready, t0.add(Duration(seconds: 1) + TvRules.rotationEvery * i)).map((TvUtterance u) => u.text),
    ];
    expect(rotated, <String>[
      'Commande 0. 2. est prête. 2 Ndolé. Je répète : 0. 2.',
      'Commande 0. 1. est prête. 2 Ndolé. Je répète : 0. 1.',
      'Commande 0. 2. est prête. 2 Ndolé. Je répète : 0. 2.',
    ]);
  });

  test('a ticket that left stops rotating; nothing ready means no rotation', () {
    step(const <PosOrder>[], t0);
    step(<PosOrder>[order('a', status: PosOrderStatus.ready)], t0);
    expect(step(const <PosOrder>[], t0.add(TvRules.rotationEvery * 3)), isEmpty);
  });

  test('a ticket sent back and made ready again is announced again', () {
    step(const <PosOrder>[], t0);
    step(<PosOrder>[order('a', status: PosOrderStatus.ready)], t0);
    step(<PosOrder>[order('a', status: PosOrderStatus.preparing)], t0.add(const Duration(seconds: 5)));
    final DateTime t2 = t0.add(const Duration(seconds: 10));
    expect(step(<PosOrder>[order('a', status: PosOrderStatus.ready, changed: t2)], t2).single.priority, TvUtterancePriority.ready);
  });
}
