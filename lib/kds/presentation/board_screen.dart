import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import '../access/kds_view.dart';
import '../access/kds_view_controller.dart';
import '../domain/kds_lanes.dart';
import '../link/kds_link.dart';
import '../state/kds_board.dart';
import '../theme/kds_scale.dart';
import 'widgets/kds_scrollable.dart';
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
    final String? view = ref.watch(kdsViewProvider);

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
                  title: view == KdsView.cashier
                      ? l10n.kdsViewCashier
                      : l10n.kdsBoardTitle,
                  // « Changer de vue » — only once a view was chosen.
                  onSwitchView: view == null
                      ? null
                      : ref.read(kdsViewProvider.notifier).clear,
                ),
                const SizedBox(height: KdsScale.gapMd),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      final List<String> lanes = KdsView.restrict(
                        KdsLane.visible(board.lanes),
                        view,
                      );
                      final double width = KdsScale.laneWidthFor(
                        available: box.maxWidth,
                        count: lanes.length,
                      );
                      // One size for every heading, chosen from the longest —
                      // see [KdsScale.laneTitleSize].
                      final TextStyle base = Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(
                            fontSize: KdsScale.titleSize,
                            fontWeight: FontWeight.w700,
                          );
                      // The chip is measured at its own style, for the widest
                      // count actually on the board.
                      final TextStyle countStyle = Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(
                            fontSize: KdsScale.bodySize,
                            fontWeight: FontWeight.w800,
                          );
                      final TextScaler scaler = MediaQuery.textScalerOf(
                        context,
                      );
                      double chip = 0;
                      for (final String lane in lanes) {
                        final double w = _measure(
                          '${board.lane(lane).length}',
                          countStyle,
                          scaler,
                        );
                        if (w > chip) {
                          chip = w;
                        }
                      }
                      final double titleSize = KdsScale.laneTitleSize(
                        titles: <String>[
                          for (final String lane in lanes)
                            _laneTitle(l10n, lane),
                        ],
                        laneWidth: width,
                        countChipWidth: chip + KdsScale.laneCountChipPadding,
                        measure: (String text) => _measure(text, base, scaler),
                      );
                      // ⚠ **Centred when they do not fill the board.** At a
                      // 1080p TV geometry the lanes used to sit hard against
                      // the left with a third of the screen empty beside
                      // them. They grow first (see `laneWidthMax`); whatever
                      // is still left over is split evenly so the board reads
                      // as a board rather than as a panel that failed to
                      // load.
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: _sideGutter(
                            available: box.maxWidth,
                            laneWidth: width,
                            lanes: lanes.length,
                          ),
                        ),
                        children: <Widget>[
                          for (final (int index, String lane) in lanes.indexed)
                            _Lane(
                              width: width,
                              titleSize: titleSize,
                              // ⚠ Owner, 2026-11-23: *"make distinction in
                              // columns by alternating their background color
                              // light level"*. Four columns of the same white
                              // on one cream field give the eye nothing but a
                              // hairline to find a lane edge by, from two
                              // metres, in a kitchen.
                              tinted: index.isOdd,
                              title: _laneTitle(l10n, lane),
                              orders: board.lane(lane),
                              linesOf: board.linesOf,
                              now: board.now,
                              emptyLabel: l10n.kdsLaneEmpty,
                              onAction: (PosOrder order) =>
                                  order.status == PosOrderStatus.pendingPayment
                                  ? controller.settleCash(order.clientId)
                                  : controller.advance(order),
                              // Only the till removes tickets, and only the
                              // unpaid ones it holds (S10).
                              onDelete: lane == KdsLane.counter
                                  ? (PosOrder order) => _confirmDelete(
                                      context,
                                      order,
                                      controller,
                                    )
                                  : null,
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

  /// What to leave on each side so the lanes sit in the middle of a board
  /// they do not fill. Zero whenever they do — a board that scrolls must
  /// start at its first lane.
  static double _sideGutter({
    required double available,
    required double laneWidth,
    required int lanes,
  }) {
    if (lanes <= 0) {
      return 0;
    }
    // Each lane carries its own right margin (`KdsScale.gapMd`).
    final double used = lanes * (laneWidth + KdsScale.gapMd);
    final double slack = available - used;
    return slack <= 0 ? 0 : slack / 2;
  }

  /// The width [text] would take at [style]. A `TextPainter` rather than a
  /// widget, because the size has to be known BEFORE the headings are built —
  /// they all have to agree on it.
  ///
  /// ⚠⚠ **[scaler] is not optional, and leaving it out is why this defect
  /// survived three attempts.** The Samsung in the kitchen is set to font
  /// scale **1.1** — a perfectly ordinary accessibility setting — so every
  /// heading rendered 10% wider than this function said it would, and *En
  /// préparation* kept coming back as *"En préparat…"* while the arithmetic
  /// insisted it fitted. A measurement that ignores the viewer's own text
  /// scale is not a measurement of what the viewer sees.
  static double _measure(String text, TextStyle style, TextScaler scaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
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
    required this.title,
    this.onSwitchView,
  });

  final String title;
  final KdsBoardState board;
  final KdsLinkState link;
  final VoidCallback onMute;
  final VoidCallback onRepair;
  final VoidCallback? onSwitchView;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    // ⚠ **The header has to survive a board nobody designed it for.** Measured
    // 2026-11-23 at 640x400 dp: the logo, the title, the offline badge and
    // *Couper l'alarme* ran 75 px past the right edge, and the overflow stripe
    // was drawn straight through the mute button. Owner, same day: *"kitchen
    // and born should fit any size cause it could be displayed on tv"* — which
    // cuts both ways, and the small end is where things break.
    //
    // Compact keeps every control and every touch target; only the WORDS go.
    // An icon-only badge and mute button still carry their meaning to a screen
    // reader, and a 72 dp target is a 72 dp target either way.
    final bool compact = MediaQuery.sizeOf(context).width < 760;
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
                // ⚠ The wordmark asset is GOLD (for green screens). On this
                // cream header it was near-invisible on the Samsung
                // (2026-11-25), so it is tinted brand green here; "eats" is
                // knocked out of the pill, so the tint keeps it legible.
                color: AppColors.primary,
                colorBlendMode: BlendMode.srcIn,
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
            // The view's own name: « Caisse paiement » must not read « Cuisine ».
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: compact ? KdsScale.titleSize : KdsScale.headlineSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: KdsScale.gapLg),
        const Spacer(),
        // ⚠ **The badge is not decoration.** A board that has silently lost the
        // kiosk looks exactly like a board with no orders — same empty lanes,
        // same calm screen — and a kitchen cannot tell those apart without
        // being told. It is the only way "quiet evening" and "the wifi died"
        // are distinguishable from across a kitchen.
        if (!link.connected) ...<Widget>[
          Semantics(
            label: l10n.kdsOffline,
            child: ExcludeSemantics(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? KdsScale.gap : KdsScale.gapMd,
                  vertical: KdsScale.gap,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(KdsScale.gap),
                ),
                child: compact
                    ? Icon(
                        Icons.wifi_off,
                        size: KdsScale.labelSize + 4,
                        color: theme.colorScheme.onError,
                      )
                    : Text(
                        l10n.kdsOffline,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onError,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: KdsScale.gapMd),
        ],
        // Only while it is actually making noise. A permanent mute button is a
        // button somebody presses once, out of curiosity, at 11:00.
        if (board.alarming && compact)
          // Same button, same 72 dp target, no label. A cook silencing an
          // alarm is not reading the button.
          Tooltip(
            message: l10n.kdsMuteAlarm,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(KdsScale.minTarget, KdsScale.minTarget),
                padding: EdgeInsets.zero,
              ),
              onPressed: onMute,
              child: Semantics(
                label: l10n.kdsMuteAlarm,
                button: true,
                child: const Icon(Icons.volume_off),
              ),
            ),
          )
        else if (board.alarming)
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
        if (onSwitchView != null) ...<Widget>[
          const SizedBox(width: KdsScale.gapMd),
          // ⚠ Icon only, at every width: with the label it pushed the header
          // 142 px over at 844 dp (the iPhone board) once the alarm was on
          // screen. The tooltip and the semantics label carry the words.
          Tooltip(
            message: l10n.kdsSwitchView,
            child: OutlinedButton(
              key: const Key('kds-switch-view'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(KdsScale.minTarget, KdsScale.minTarget),
                padding: EdgeInsets.zero,
              ),
              onPressed: onSwitchView,
              child: Semantics(
                label: l10n.kdsSwitchView,
                button: true,
                child: const Icon(Icons.swap_horiz),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The line box of a lane heading, as a multiple of its type size. Declared
/// once because the reserved height and the rendered text have to agree — a
/// reserved height computed from a different number is a clipped heading.
const double _laneTitleLineHeight = 1.1;

/// *Supprimer le ticket ?* — a removed ticket is a cancelled order, so the
/// cashier is asked once, with the consequence spelled out (S10).
Future<void> _confirmDelete(
  BuildContext context,
  PosOrder order,
  KdsBoardController controller,
) async {
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  final String label =
      order.ticketLabelOrNull ?? order.dailyCode ?? order.orderCode ?? '';
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      key: const Key('kds-delete-dialog'),
      title: Text(l10n.kdsDeleteTitle(label)),
      content: Text(l10n.kdsDeleteBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.kdsDeleteCancel),
        ),
        FilledButton(
          key: const Key('kds-delete-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.kdsDeleteConfirm),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    controller.cancelUnpaid(order.clientId);
  }
}

class _Lane extends StatefulWidget {
  const _Lane({
    required this.width,
    required this.titleSize,
    required this.tinted,
    required this.title,
    required this.orders,
    required this.linesOf,
    required this.now,
    required this.emptyLabel,
    required this.onAction,
    this.onDelete,
  });

  final double width;
  final double titleSize;

  /// Every other lane sits one step darker, so the columns alternate.
  final bool tinted;
  final String title;
  final List<PosOrder> orders;
  final List<PosOrderLine> Function(String clientId) linesOf;
  final DateTime now;
  final String emptyLabel;
  final void Function(PosOrder order) onAction;

  /// The trash icon on each card; null in every lane but *À encaisser*.
  final void Function(PosOrder order)? onDelete;

  @override
  State<_Lane> createState() => _LaneState();
}

class _LaneState extends State<_Lane> {
  /// One controller per lane, owned here: [KdsScrollable] listens to it to
  /// know whether there are tickets below the fold.
  final ScrollController scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: widget.width,
      margin: const EdgeInsets.only(right: KdsScale.gapMd),
      // ⚠ **A lane is a column, and a column has edges.** Screenshotted on the
      // real board 2026-11-23: four headings floating on one flat cream field,
      // with nothing saying where one queue ended and the next began. On a
      // screen read from two metres across a kitchen that is not a style
      // preference — a cook has to find THEIR lane before they can read a
      // ticket in it.
      //
      // The surface is white on the cream canvas, which is the ladder the
      // tokens already define (canvas < white card < muted field); no new
      // colour, no shadow, and a hairline border so an empty lane still has a
      // shape.
      decoration: BoxDecoration(
        // ⚠ Both steps stay ABOVE the cream page: the alternation separates
        // the lanes from each other, and the border plus the step above
        // `canvas` is what separates every lane from the board. A lane painted
        // in the page's own colour would read as a gap, not a column.
        //
        // The ticket cards inside are white and carry a 3 dp urgency border,
        // so they stand off both steps — checked on the device, not assumed.
        color: widget.tinted ? AppColors.surfaceMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(KdsScale.radius),
        border: Border.all(color: AppColors.outline),
      ),
      padding: const EdgeInsets.all(KdsScale.gapMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            // The count is the fixed part and the widget.title bends around it: a
            // lane that shows its name and hides how much work is in it has
            // the priority backwards.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                // ⚠ Sized by the board, not by this lane. Seen on the real
                // board 2026-11-23: *En préparation* rendered first as
                // *"En prépara…"*, then — with a per-lane `FittedBox` —
                // visibly smaller than *Prêtes* beside it. Four adjacent
                // columns with four type sizes read as if they were ranked.
                // The ellipsis stays as the last resort below the floor.
                // ⚠ **Two lines of room are reserved whether or not the
                // widget.title uses them.** Otherwise *En préparation* (two lines)
                // pushes its divider lower than the three one-line lanes
                // beside it, and four columns that should read as one row of
                // headings read as a ragged edge.
                child: SizedBox(
                  height:
                      widget.titleSize *
                      _laneTitleLineHeight *
                      KdsScale.laneTitleMaxLines *
                      MediaQuery.textScalerOf(context).scale(1),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      widget.title,
                      maxLines: KdsScale.laneTitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: widget.titleSize,
                        fontWeight: FontWeight.w700,
                        height: _laneTitleLineHeight,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: KdsScale.gap),
              // The count reads as a tally, not as part of the name.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.orders.isEmpty
                      // On a widget.tinted lane the muted chip would vanish into its
                      // own background.
                      ? (widget.tinted
                            ? AppColors.surface
                            : AppColors.surfaceMuted)
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(KdsScale.radiusSmall),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KdsScale.gap,
                    vertical: 2,
                  ),
                  child: Text(
                    '${widget.orders.length}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: KdsScale.bodySize,
                      fontWeight: FontWeight.w800,
                      color: widget.orders.isEmpty
                          ? AppColors.textMuted
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KdsScale.gap),
          Divider(height: 1, thickness: 1, color: AppColors.outline),
          const SizedBox(height: KdsScale.gapMd),
          Expanded(
            child: widget.orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.check_circle_outline,
                          size: 32,
                          color: AppColors.outline,
                        ),
                        const SizedBox(height: KdsScale.gap),
                        Text(
                          widget.emptyLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                // The lane's own height is passed down so no card can grow
                // taller than the space a cook can see — see
                // `KdsTicketCard.maxHeight`.
                : LayoutBuilder(
                    builder:
                        (
                          BuildContext context,
                          BoxConstraints constraints,
                        ) => KdsScrollable(
                          controller: scroll,
                          child: ListView.builder(
                            controller: scroll,
                            itemCount: widget.orders.length,
                            itemBuilder: (BuildContext context, int index) {
                              final PosOrder order = widget.orders[index];
                              final bool actionable =
                                  order.status ==
                                      PosOrderStatus.pendingPayment ||
                                  KdsLane.advanceFor(
                                        order.status,
                                        order.mode,
                                      ) !=
                                      null;
                              return KdsTicketCard(
                                // ⚠ **The front of the queue opens; the rest
                                // collapse.** Owner, 2026-11-24. Defaulting
                                // everything to collapsed would make a cook tap
                                // before they could cook; defaulting everything
                                // to open is what filled the board. Two is what
                                // a pair of hands is actually working on.
                                startExpanded: index < 2,
                                laneWidth: widget.width,
                                order: order,
                                lines: widget.linesOf(order.clientId),
                                now: widget.now,
                                // ⚠⚠ **The lane's visible height, never more.**
                                // Owner, 2026-11-24: *"be sure the user can
                                // always click on all buttons — currently
                                // Encaisser is not reachable on kitchen"*. A
                                // card taller than the lane puts its action
                                // below the fold, and a control a cook cannot
                                // reach does not exist.
                                //
                                // The card is what adapts instead: see the
                                // `compact` branch in `KdsTicketCard`, which
                                // puts the ticket code and the dishes FIRST so
                                // the little room a short screen leaves is
                                // spent on what a cook actually reads.
                                maxHeight: constraints.maxHeight,
                                onPrimaryAction: actionable
                                    ? () => widget.onAction(order)
                                    : null,
                                onDelete:
                                    widget.onDelete != null &&
                                        order.awaitsCounterPayment
                                    ? () => widget.onDelete!(order)
                                    : null,
                              );
                            },
                          ),
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}
