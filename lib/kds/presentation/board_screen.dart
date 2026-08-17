import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import '../domain/kds_lanes.dart';
import '../state/kds_board.dart';
import '../theme/kds_scale.dart';
import 'widgets/kds_ticket_card.dart';

/// The kitchen board: six lanes, oldest first, one tap per ticket.
///
/// The **counter lane comes first** because it is the lane that releases
/// tickets to the kitchen — an unpaid ticket is work nobody has agreed to do
/// yet, and putting it anywhere but first buries the one queue that gates
/// everything downstream (plan §K5).
class KdsBoardScreen extends ConsumerWidget {
  const KdsBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final KdsBoardState board = ref.watch(kdsBoardProvider);
    final KdsBoardController controller = ref.read(kdsBoardProvider.notifier);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return PopScope(
      // The kitchen board has the same rule as the kiosk (§K8): back must not
      // background a mounted, unattended tablet mid-service.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KdsScale.gapLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Header(board: board),
                const SizedBox(height: KdsScale.gapMd),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      for (final String lane in KdsLane.all)
                        _Lane(
                          title: _laneTitle(l10n, lane),
                          orders: board.lane(lane),
                          now: board.now,
                          emptyLabel: l10n.kdsLaneEmpty,
                          onAction: (PosOrder order) =>
                              order.status == PosOrderStatus.pendingPayment
                              ? controller.settleCash(order.clientId)
                              : controller.advance(order),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _laneTitle(AppLocalizations l10n, String lane) =>
      switch (lane) {
        KdsLane.counter => l10n.kdsLaneCounter,
        KdsLane.scheduled => l10n.kdsLaneScheduled,
        KdsLane.newTickets => l10n.kdsLaneNew,
        KdsLane.preparing => l10n.kdsLanePreparing,
        KdsLane.ready => l10n.kdsLaneReady,
        _ => l10n.kdsLaneOutForDelivery,
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.board});

  final KdsBoardState board;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(
          l10n.kdsBoardTitle,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: KdsScale.headlineSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: KdsScale.gapLg),
        // One summary line, never one alert per ticket: a board that shouts
        // eleven times while a cook is plating is a board the cook stops
        // hearing (§22.1).
        if (board.expiredJustNow > 0)
          Text(
            l10n.kdsExpired(board.expiredJustNow),
            style: theme.textTheme.labelLarge,
          ),
        const Spacer(),
        if (board.lastError != null)
          Text(
            board.lastError!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.title,
    required this.orders,
    required this.now,
    required this.emptyLabel,
    required this.onAction,
  });

  final String title;
  final List<PosOrder> orders;
  final DateTime now;
  final String emptyLabel;
  final void Function(PosOrder order) onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: KdsScale.laneWidth,
      margin: const EdgeInsets.only(right: KdsScale.gapMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: KdsScale.titleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: KdsScale.gap),
              Text(
                '${orders.length}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: KdsScale.titleSize,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: KdsScale.gapMd),
          Expanded(
            child: orders.isEmpty
                ? Text(emptyLabel, style: theme.textTheme.labelLarge)
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (BuildContext context, int index) {
                      final PosOrder order = orders[index];
                      final bool actionable =
                          order.status == PosOrderStatus.pendingPayment ||
                          KdsLane.advanceFor(order.status, order.mode) != null;
                      return KdsTicketCard(
                        order: order,
                        now: now,
                        onPrimaryAction: actionable
                            ? () => onAction(order)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
