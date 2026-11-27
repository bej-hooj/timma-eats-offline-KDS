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

  /// [silent] = how long the voice has been quiet (null = speaking).
  List<TvUtterance> step(List<PosOrder> orders, DateTime now, {Duration? silent = Duration.zero}) =>
      announcer.next(board(orders, now), now, silentFor: silent);

  test('the first board after launch is silent', () {
    expect(step(<PosOrder>[order('a'), order('b', status: PosOrderStatus.ready)], t0), isEmpty);
  });

  test('a new ticket is announced once, then silence on re-reads', () {
    step(const <PosOrder>[], t0);
    final List<TvUtterance> first = step(<PosOrder>[order('a', number: 7)], t0);
    expect(first.single.text, 'Commande 0. 7. en préparation. Je répète : 0. 7.');
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

  test('re-read cycle: after 20 s of silence, every « Prêt » then every « En préparation »', () {
    step(const <PosOrder>[], t0);
    final List<PosOrder> orders = <PosOrder>[
      order('p', number: 3, placed: t0),
      order('a', number: 1, status: PosOrderStatus.ready, changed: t0),
      order('b', number: 2, status: PosOrderStatus.ready, changed: t0.add(const Duration(seconds: 1))),
    ];
    final DateTime t1 = t0.add(const Duration(seconds: 1));
    expect(step(orders, t1), hasLength(3)); // fresh: 1 preparing + 2 ready
    // Silent, but not long enough yet; and nothing while still speaking.
    expect(step(orders, t1, silent: const Duration(seconds: 19)), isEmpty);
    expect(step(orders, t1, silent: null), isEmpty);
    final List<TvUtterance> cycle = step(orders, t1, silent: TvRules.cyclePause);
    expect(cycle.map((TvUtterance u) => u.text), <String>[
      'Commande 0. 2. est prête. 2 Ndolé. Je répète : 0. 2.',
      'Commande 0. 1. est prête. 2 Ndolé. Je répète : 0. 1.',
      'Commande 0. 3. en préparation. Je répète : 0. 3.',
    ]);
    expect(cycle.every((TvUtterance u) => u.reread && !u.chime), isTrue);
  });

  test('a fresh move wins over the cycle; an empty board has no cycle', () {
    step(const <PosOrder>[], t0);
    step(<PosOrder>[order('p', number: 3)], t0);
    final List<TvUtterance> said = step(
      <PosOrder>[order('p', number: 3), order('n', number: 4)],
      t0,
      silent: TvRules.cyclePause,
    );
    expect(said.single.reread, isFalse);
    expect(step(const <PosOrder>[], t0, silent: TvRules.cyclePause * 3), isEmpty);
  });

  test('a ticket sent back and made ready again is announced again', () {
    step(const <PosOrder>[], t0);
    step(<PosOrder>[order('a', status: PosOrderStatus.ready)], t0);
    step(<PosOrder>[order('a', status: PosOrderStatus.preparing)], t0.add(const Duration(seconds: 5)));
    final DateTime t2 = t0.add(const Duration(seconds: 10));
    expect(step(<PosOrder>[order('a', status: PosOrderStatus.ready, changed: t2)], t2).single.priority, TvUtterancePriority.ready);
  });
}
