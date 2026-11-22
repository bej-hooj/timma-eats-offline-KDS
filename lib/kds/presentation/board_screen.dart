import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import '../domain/kds_lanes.dart';
import '../link/kds_link.dart';
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
    final KdsLinkState link = ref.watch(kdsLinkProvider);
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
                _Header(
                  board: board,
                  link: link,
                  onMute: controller.muteAlarm,
                  onRepair: () => _confirmRepair(context, ref),
                ),
                const SizedBox(height: KdsScale.gapMd),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      final List<String> lanes = KdsLane.visible(board.lanes);
                      final double width = KdsScale.laneWidthFor(
                        available: box.maxWidth,
                        count: lanes.length,
                      );
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        children: <Widget>[
                          for (final String lane in lanes)
                            _Lane(
                              width: width,
                              title: _laneTitle(l10n, lane),
                              orders: board.lane(lane),
                              linesOf: board.linesOf,
                              now: board.now,
                              emptyLabel: l10n.kdsLaneEmpty,
                              onAction: (PosOrder order) =>
                                  order.status == PosOrderStatus.pendingPayment
                                  ? controller.settleCash(order.clientId)
                                  : controller.advance(order),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠ **The board must never be a dead end.** A tablet whose kiosk was
  /// replaced, or one a manager wants to move to a different kiosk, had no
  /// route back to the pairing screen from the product — the only way out was
  /// to reinstall the app, and on iOS even that does not clear the keychain.
  /// The kiosk has had a long-press manager gate since K8; the board now has
  /// the same gesture, for the same reason.
  static Future<void> _confirmRepair(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.kdsRepairTitle),
        content: Text(l10n.kdsRepairBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.kdsRepairCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.kdsRepairConfirm),
          ),
        ],
      ),
    );
    if (yes ?? false) {
      await ref.read(kdsLinkProvider.notifier).stop();
      ref.read(kdsIdentityProvider.notifier).requirePairing();
    }
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
  const _Header({
    required this.board,
    required this.link,
    required this.onMute,
    required this.onRepair,
  });

  final KdsBoardState board;
  final KdsLinkState link;
  final VoidCallback onMute;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        // The TIMMA logo, so a kitchen tablet on a shelf of tablets is
        // identifiable at a glance. Sized to the header's own type scale rather
        // than to a constant, and it degrades to nothing rather than to a
        // broken-image box — the board's job is tickets, not branding.
        // The logo is the gate. Long press, like the kiosk's — a gesture a
        // cook will not hit by accident and a manager can be told once.
        GestureDetector(
          onLongPress: onRepair,
          behavior: HitTestBehavior.opaque,
          // ⚠ The target is sized here, not by the logo. The image degrades to
          // `SizedBox.shrink()` when the asset cannot be decoded, and a
          // zero-sized escape hatch is no escape hatch — the one gesture that
          // rescues a board from a kiosk that no longer knows it would vanish
          // with the artwork. A touch target the manager can find exists
          // whether or not there is a picture in it.
          child: SizedBox(
            width: KdsScale.minTarget,
            height: KdsScale.minTarget,
            child: Center(
              child: Image.asset(
                'assets/branding/logo_inline.png',
                height: KdsScale.headlineSize,
                fit: BoxFit.contain,
                errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        const SizedBox(width: KdsScale.gapMd),
        // Flexible too. Everything on this row that is *words* gives way; the
        // badge and the mute button are the only fixed things, because they are
        // the only things a cook acts on.
        Flexible(
          child: Text(
            l10n.kdsBoardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: KdsScale.headlineSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: KdsScale.gapLg),
        // One summary line, never one alert per ticket: a board that shouts
        // eleven times while a cook is plating is a board the cook stops
        // hearing (§22.1).
        // ⚠ **Flexible, not a bare `Text`.** This row holds the logo, the
        // title, this line, the offline badge and *Couper l'alarme*, and on the
        // 844 dp board it ran 44 px over the moment the expiry line and the
        // alarm were on screen together — seen on the simulator, with the
        // stripe drawn straight through the mute button. The sentence gives
        // way; the control never does.
        if (board.expiredJustNow > 0)
          Flexible(
            child: Text(
              l10n.kdsExpired(board.expiredJustNow),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
        const Spacer(),
        // ⚠ **The badge is not decoration.** A board that has silently lost the
        // kiosk looks exactly like a board with no orders — same empty lanes,
        // same calm screen — and a kitchen cannot tell those apart without
        // being told. It is the only way "quiet evening" and "the wifi died"
        // are distinguishable from across a kitchen.
        if (!link.connected) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KdsScale.gapMd,
              vertical: KdsScale.gap,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.error,
              borderRadius: BorderRadius.circular(KdsScale.gap),
            ),
            child: Text(
              l10n.kdsOffline,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onError,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: KdsScale.gapMd),
        ],
        // Only while it is actually making noise. A permanent mute button is a
        // button somebody presses once, out of curiosity, at 11:00.
        if (board.alarming)
          FilledButton.icon(
            // ⚠ The theme's `minimumSize` is `Size.fromHeight` — **infinite
            // width** — because every other button on this board is a full-width
            // card action. In a `Row` that is an unbounded-width crash, not a
            // wide button. The height floor is the rule that matters (72 dp for
            // a gloved hand) and it is kept; only the width opt-out changes.
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, KdsScale.minTarget),
            ),
            onPressed: onMute,
            icon: const Icon(Icons.volume_off),
            label: Text(l10n.kdsMuteAlarm),
          )
        else if (board.alarmMuted)
          Text(
            l10n.kdsAlarmMuted,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        if (board.lastError != null) const SizedBox(width: KdsScale.gapMd),
        if (board.lastError != null)
          Flexible(
            child: Text(
              board.lastError!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.width,
    required this.title,
    required this.orders,
    required this.linesOf,
    required this.now,
    required this.emptyLabel,
    required this.onAction,
  });

  final double width;
  final String title;
  final List<PosOrder> orders;
  final List<PosOrderLine> Function(String clientId) linesOf;
  final DateTime now;
  final String emptyLabel;
  final void Function(PosOrder order) onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: width,
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
                // The lane's own height is passed down so no card can grow
                // taller than the space a cook can see — see
                // `KdsTicketCard.maxHeight`.
                : LayoutBuilder(
                    builder:
                        (
                          BuildContext context,
                          BoxConstraints constraints,
                        ) => ListView.builder(
                          itemCount: orders.length,
                          itemBuilder: (BuildContext context, int index) {
                            final PosOrder order = orders[index];
                            final bool actionable =
                                order.status == PosOrderStatus.pendingPayment ||
                                KdsLane.advanceFor(order.status, order.mode) !=
                                    null;
                            return KdsTicketCard(
                              order: order,
                              lines: linesOf(order.clientId),
                              now: now,
                              maxHeight: constraints.maxHeight,
                              onPrimaryAction: actionable
                                  ? () => onAction(order)
                                  : null,
                            );
                          },
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}
