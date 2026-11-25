import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/design/money_formatter.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import '../../domain/kds_lanes.dart';
import '../../menu/kds_dish_photos.dart';
import '../../theme/kds_scale.dart';

/// One ticket, carrying its identity (ECOSYSTEM §1.6).
///
/// **Every card states its `source` and its money state**, because *take cash*
/// and *already paid* must never be confusable — a cook who reads one as the
/// other either hands out free food or asks a customer to pay twice. A
/// paid-online ticket enters the cook lane directly and never shows a cash
/// button at all.
class KdsTicketCard extends StatefulWidget {
  const KdsTicketCard({
    required this.order,
    required this.lines,
    required this.now,
    required this.onPrimaryAction,
    this.onDelete,
    this.maxHeight,
    this.startExpanded = true,
    this.laneWidth = 0,
    super.key,
  });

  final PosOrder order;

  /// ⚠ **What the customer actually ordered.** The card showed a ticket number
  /// and a total; a cook cannot cook a total, and the kitchen was reading the
  /// board and then asking the counter what was in the order. The lines have
  /// been arriving on the wire since K3 — `BoardOrder` carries them — and this
  /// card discarded them.
  final List<PosOrderLine> lines;

  final DateTime now;

  /// Settle for an unpaid counter ticket, advance for anything else. Null when
  /// the ticket offers neither.
  final VoidCallback? onPrimaryAction;

  /// The cashier's trash icon beside *Encaisser* (S10). Null everywhere else.
  final VoidCallback? onDelete;

  /// The tallest this card may be — the lane's own height.
  ///
  /// ⚠⚠ **This is what keeps the action reachable.** The card is a single
  /// column of chips, ticket number, every line, the note and the total, with
  /// the button last. On the Samsung the kitchen runs on — **411 dp tall in
  /// landscape** — a four-line ticket is taller than the lane, so the button
  /// sat below the fold and a cook could not advance the ticket **at all**.
  /// Seen on the device today: *Ticket 01* arrived, and there was no way to
  /// touch it.
  ///
  /// The same mistake as the pairing screen in August, where the test asserted
  /// the button EXISTED and passed while it was off screen. A control a cook
  /// cannot reach is a control that does not exist.
  final double? maxHeight;

  /// Whether this card opens showing its dishes.
  ///
  /// ⚠ **Owner, 2026-11-24:** *"for space, for better rendering, tickets
  /// should have collapse and just show their number, then user expands to
  /// see everything ordered inside"*.
  ///
  /// The lane decides: the tickets a cook is working on NOW open, the queue
  /// behind them collapses to a line each. Defaulting everything to collapsed
  /// would make a cook tap before they could cook, and defaulting everything
  /// to open is what filled the board in the first place.
  final bool startExpanded;

  /// How wide the lane holding this card is. Passed rather than measured: the
  /// card decides its type step from it, and a `MediaQuery` would give it the
  /// whole board instead of its own column.
  final double laneWidth;

  @override
  State<KdsTicketCard> createState() => _KdsTicketCardState();
}

class _KdsTicketCardState extends State<KdsTicketCard> {
  late bool _expanded = widget.startExpanded;

  @override
  void didUpdateWidget(KdsTicketCard old) {
    super.didUpdateWidget(old);
    // A ticket that moves lane (or that the lane re-ranks) takes the lane's
    // new suggestion; a cook's own tap is not undone by a board refresh,
    // which happens every five seconds.
    if (old.startExpanded != widget.startExpanded) {
      _expanded = widget.startExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final PosOrder order = widget.order;
    final List<PosOrderLine> lines = widget.lines;
    final DateTime now = widget.now;
    final double? maxHeight = widget.maxHeight;
    final VoidCallback? onPrimaryAction = widget.onPrimaryAction;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final KdsUrgency urgency = KdsSla.urgencyOf(order, now);
    // Local ticket code first (it is on the printed slip the customer holds),
    // then the server's kitchen code, then the order code.
    final String? identity =
        order.ticketLabelOrNull ??
        _clean(order.dailyCode) ??
        _clean(order.orderCode);
    final Duration waiting = now.difference(KdsSla.agedFrom(order));
    final int waited = waiting.inMinutes;
    final bool paid = order.paymentStatus == PosPaymentStatus.paid;
    final bool french = Localizations.localeOf(context).languageCode == 'fr';

    // ⚠ **A card on a short screen is a different card.** The kitchen Samsung
    // is 411 dp tall in landscape, which leaves a lane about 153 dp — and the
    // full-size card spends 72 of those on its button alone. Rather than drop
    // what a cook needs (which is what the old height cap did), the card
    // tightens: smaller padding, a smaller action, and a total that scales to
    // one line instead of wrapping into "5 100 FCF / A".
    final bool compact = (maxHeight ?? double.infinity) < 320;
    final double pad = compact ? KdsScale.gap : KdsScale.gapMd;

    // ⚠ **A board on a wall is read from metres away.** Rendered at a 1080p
    // TV geometry on 2026-11-25: the card's tablet-sized type looked like
    // small print on a room-sized screen. Above [KdsScale.laneWidthLarge] the
    // card prints a step larger — the dish, the code and the total, which are
    // the three things a cook reads at distance.
    final bool large = !compact && widget.laneWidth >= KdsScale.laneWidthLarge;
    final double step = large ? 1.25 : 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: KdsScale.gapMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KdsScale.radius),
        // Urgency is a border, not a fill: a red-filled card at 20 minutes
        // makes its own text harder to read exactly when it matters most.
        side: BorderSide(color: _urgencyColor(theme, urgency), width: 3),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Everything a cook READS scrolls; the thing a cook PRESSES does
              // not. The button is a sibling of this box, never inside it.
              Flexible(
                // ⚠ The whole readable area toggles, not a small chevron: a
                // cook with a gloved wet hand aims at a card, not at a 24 dp
                // glyph. The action button is a SIBLING of this box, so
                // pressing it can never be mistaken for opening the ticket.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ⚠ On a short board the chips go BELOW. A 411 dp
                        // screen leaves this scroll area about 70 dp, and what
                        // belongs in it is the ticket code and the dish — not
                        // "Borne" and "Non payé", which a cook can scroll to.
                        if (compact) ...<Widget>[
                          if (identity != null)
                            Text(
                              l10n.kdsTicket(identity),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: KdsScale.bodySize,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          for (final PosOrderLine line in lines)
                            _Line(
                              line: line,
                              french: french,
                              l10n: l10n,
                              step: step,
                            ),
                          if (lines.isEmpty)
                            Text(
                              l10n.kdsLinesPending,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          const SizedBox(height: KdsScale.gap),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Wrapped, not a fixed Row: the French money-state label
                            // ("À encaisser") plus a source chip overflowed a 320-wide
                            // lane, and a card that clips its own money state is the one
                            // thing §1.6 says it must never do.
                            Expanded(
                              child: Wrap(
                                spacing: KdsScale.gap,
                                runSpacing: 4,
                                children: <Widget>[
                                  _Chip(
                                    label: _sourceLabel(l10n, order.source),
                                    color: AppColors.primarySoft,
                                    textColor: AppColors.primary,
                                  ),
                                  _Chip(
                                    label: paid ? l10n.kdsPaid : l10n.kdsUnpaid,
                                    color: paid
                                        ? AppColors.primary
                                        : theme.colorScheme.error,
                                    textColor: paid
                                        ? AppColors.onPrimary
                                        : theme.colorScheme.onError,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: KdsScale.gap),
                            // ⚠ Flexible: on a narrow lane the chips beside it
                            // take what they need and this ran 8.5 px over.
                            // The age gives way before the money state does.
                            Flexible(
                              child: Text(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                // ⚠ **Hours past three of them, never minutes.**
                                // Seen on the real board 2026-11-23: a ticket
                                // synced down from the cloud read **142411 min**,
                                // which is three months expressed in a unit for
                                // tens. It is not a wrong number — it is a number
                                // in a unit nobody can read, on the mark a cook is
                                // meant to glance at. A board whose urgency mark
                                // is noise is a board that trains people to ignore
                                // the mark.
                                waiting < const Duration(hours: 3)
                                    ? l10n.kdsWaitingMinutes(waited)
                                    : l10n.kdsWaitingLong(waiting.inHours),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: _urgencyColor(theme, urgency),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: KdsScale.gapMd),
                        /*
             * ⚠ The STATION, not just the number.
             *
             * `allocateTicketNumber` counts per till and restarts at 1 every
             * Douala day, so a branch running two bornes prints two #1s — and
             * this board is exactly where they meet. `ticketLabelOrNull`
             * renders `B1-07`, and falls back to the bare number for a sale
             * written before stations existed rather than inventing a letter:
             * a wrong station sends a cook to the wrong customer, which is
             * worse than no station at all.
             */
                        // ⚠ A ticket from the CLOUD has no local number — it was
                        // not printed by any borne here — so it fell through
                        // this `if` and the card carried NOTHING a cook could
                        // call out. `daily_code` is the kitchen's own code,
                        // minted by the server for exactly this (ECOSYSTEM
                        // §6.4), and `order_code` is the last resort.
                        if (identity != null && !compact)
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  l10n.kdsTicket(identity),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: KdsScale.titleSize * step,
                                  ),
                                ),
                              ),
                              // ⚠ The affordance has to be VISIBLE. A card that
                              // can be opened but does not look like it is a
                              // card nobody opens.
                              Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        // ⚠ **Collapsed, a ticket is one line.** Owner,
                        // 2026-11-24: the board filled up with open tickets and
                        // a cook could not see the queue. Collapsed it still
                        // carries the two things that decide whether to open
                        // it — how much is on it and what it comes to — and the
                        // action stays pressable without opening anything.
                        if (!_expanded && !compact) ...<Widget>[
                          const SizedBox(height: KdsScale.gap),
                          Text(
                            '${l10n.kdsItems(_itemCount(lines))}  ·  '
                            '${MoneyFormatter.formatXaf(order.total)}',
                            key: const Key('kds-ticket-summary'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: KdsScale.labelSize,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                        if (_expanded &&
                            lines.isNotEmpty &&
                            !compact) ...<Widget>[
                          const SizedBox(height: KdsScale.gapMd),
                          for (final PosOrderLine line in lines)
                            _Line(
                              line: line,
                              french: french,
                              l10n: l10n,
                              step: step,
                            ),
                        ] else if (_expanded &&
                            lines.isEmpty &&
                            !compact) ...<Widget>[
                          // ⚠ A card with no dishes on it looks like a bug, and
                          // a cook cannot tell "nothing ordered" from "the
                          // detail has not arrived". Say which.
                          const SizedBox(height: KdsScale.gapMd),
                          Text(
                            l10n.kdsLinesPending,
                            key: const Key('kds-lines-pending'),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (_expanded &&
                            order.note != null &&
                            order.note!.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: KdsScale.gap),
                          // A note is an instruction from a person, not decoration: it is
                          // given its own emphasis so it cannot be skimmed past.
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(KdsScale.gap),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(KdsScale.gap),
                            ),
                            child: Text(
                              order.note!.trim(),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: KdsScale.labelSize,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        if (_expanded)
                          SizedBox(height: compact ? 2 : KdsScale.gap),
                        if (_expanded)
                          // ⚠ One line, always. Seen on the Samsung: the total
                          // wrapped to "5 100 FCF / A" and the second line was
                          // clipped by the card. `scaleDown` only ever shrinks.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                MoneyFormatter.formatXaf(order.total),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: compact
                                      ? KdsScale.bodySize
                                      : KdsScale.totalSize * step,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onPrimaryAction != null) ...<Widget>[
                const SizedBox(height: KdsScale.gapMd),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        // ⚠ 72 dp is the gloved-hand rule and it stands on any
                        // normal board. On a 411 dp screen it is half the lane, so
                        // a short board gets 56 — still well past the 48 dp floor
                        // every platform asks for, and the alternative was a card
                        // with no room to say what to cook.
                        height: compact ? 56 : KdsScale.minTarget,
                        child: FilledButton(
                          onPressed: onPrimaryAction,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _actionLabel(l10n, order),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.onDelete != null) ...<Widget>[
                      const SizedBox(width: KdsScale.gap),
                      SizedBox.square(
                        dimension: compact ? 56 : KdsScale.minTarget,
                        child: IconButton.outlined(
                          key: const Key('kds-delete-ticket'),
                          tooltip: l10n.kdsDeleteTooltip,
                          onPressed: widget.onDelete,
                          color: theme.colorScheme.error,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// How many dishes are on the ticket — the sum of the quantities, not the
  /// number of lines. "2 articles" for one line of two is what a cook counts
  /// into a bag.
  static int _itemCount(List<PosOrderLine> lines) =>
      lines.fold<int>(0, (int sum, PosOrderLine l) => sum + l.quantity);

  static String? _clean(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Color _urgencyColor(ThemeData theme, KdsUrgency urgency) => switch (urgency) {
    KdsUrgency.calm => AppColors.outline,
    KdsUrgency.amber => const Color(0xFFB26A00),
    KdsUrgency.red => theme.colorScheme.error,
  };

  String _sourceLabel(AppLocalizations l10n, String source) => switch (source) {
    PosOrderSource.kiosk => l10n.kdsSourceKiosk,
    PosOrderSource.app => l10n.kdsSourceApp,
    _ => l10n.kdsSourceWeb,
  };

  /// The label names the **transition the status allows**, not the lane. See
  /// [KdsLane.advanceFor].
  static String _actionLabel(AppLocalizations l10n, PosOrder order) {
    if (order.status == PosOrderStatus.pendingPayment) {
      return l10n.kdsSettleCash;
    }
    return switch (KdsLane.advanceFor(order.status, order.mode)) {
      PosOrderStatus.accepted => l10n.kdsAccept,
      PosOrderStatus.preparing => l10n.kdsStartPreparing,
      PosOrderStatus.ready => l10n.kdsMarkReady,
      PosOrderStatus.outForDelivery => l10n.kdsSendOut,
      PosOrderStatus.completed => l10n.kdsHandOver,
      _ => l10n.kdsComplete,
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(KdsScale.gap),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KdsScale.gap,
          vertical: 4,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: KdsScale.labelSize,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

/// One ordered line, as a cook needs to read it across a kitchen.
///
/// **Quantity first and heavy**, because "2 ×" mis-read as "1 ×" is a remake.
/// The variant and the chosen options sit under the name, indented and lighter:
/// they qualify the dish rather than being separate work, and a cook scanning a
/// rush reads the dish names down the card first.
///
/// ⚠ A REMOVAL is not one of those. It gets its own line, in the error colour
/// and in capitals, because it is the one thing on the card that changes what
/// the cook must NOT do.
class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.french,
    required this.l10n,
    this.step = 1.0,
  });

  final PosOrderLine line;
  final bool french;
  final AppLocalizations l10n;

  /// Type multiplier for a wall-mounted board — see `KdsScale.laneWidthLarge`.
  final double step;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? variant = french ? line.variantNameFr : line.variantNameEn;
    /*
     * ⚠⚠ **Q69 — group by group, and the DECLINED groups are said out loud.**
     *
     * Owner, 2026-09-02: *"ALl the accompagnement. pepper or not and every
     * informations. Do the same on the Offline KDS"*.
     *
     * `line.modifiers` is a flat list of what was CHOSEN and names no group, so
     * a dish that offered *Piment* and was given none looked exactly like a
     * dish that never offered it — and a cook cannot tell those apart on a
     * board glanced at from two metres. `modifierGroups` (migration 63, carried
     * to the tablet by migration 64) holds the question as well as the answer,
     * so an empty option list prints as *"Piment : AUCUN"*.
     *
     * ⚠ The fallback is the only honest thing a pre-migration-63 row can say:
     * those rows have no groups at all, so they print the flat list they always
     * printed. It is not a second style, it is a different fact.
     */
    String option(PosLineModifier m) => m.quantity > 1
        ? '${m.quantity} × ${french ? m.nameFr : m.nameEn}'
        : (french ? m.nameFr : m.nameEn);

    final List<String> options = line.modifierGroups.isNotEmpty
        ? <String>[
            for (final PosLineGroup g in line.modifierGroups)
              l10n.kdsGroupLabel(
                french ? g.nameFr : g.nameEn,
                g.options.isEmpty
                    ? l10n.kdsGroupNone
                    : g.options.map(option).join(', '),
              ),
          ]
        : <String>[for (final PosLineModifier m in line.modifiers) option(m)];
    /*
     * R2 (migrations 49 + 52) — what the customer asked to LEAVE OUT.
     *
     * ⚠ Its own line, in the ERROR colour, in CAPITALS, and never joined into
     * `options` above. A cook reads the two in opposite directions: a modifier
     * is something to add, a removal is something to withhold, and a removal
     * printed among the extras reads as "add onion" — the exact opposite of
     * what the customer asked for. This board is skimmed at arm's length while
     * somebody is cooking; it has to be impossible to misread.
     */
    final List<String> removed = <String>[
      for (final PosRemovedIngredient i in line.removedIngredients)
        l10n.kdsWithout((french ? i.nameFr : i.nameEn).toUpperCase()),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: KdsScale.gap),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          // ⚠ **The picture is the first thing to go, and it goes quietly.**
          // Measured at 640x400 dp: four lanes leave a ticket line about
          // 96 dp, and a 52 dp thumbnail beside the quantity ran 10 px over —
          // an overflow stripe across a kitchen ticket. The dish NAME is what
          // a cook cooks from; the photograph is a recognition aid, so it
          // shrinks to what is left and disappears rather than push the words
          // off their own line.
          final double slack =
              box.maxWidth - _quantityColumn - KdsScale.gap - _nameFloor;
          final double thumb = slack.clamp(0, KdsScale.thumbSide);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Picture, then quantity, then the dish. The photograph is the
              // fastest thing to recognise from two metres and the quantity is
              // the thing that must not be got wrong, so they are adjacent and
              // in that order. The picture never takes the quantity's weight.
              if (thumb >= _thumbFloor) ...<Widget>[
                KdsDishPhoto(productId: line.productId, side: thumb),
                const SizedBox(width: KdsScale.gap),
              ],
              SizedBox(
                width: 44,
                child: Text(
                  '${line.quantity} ×',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: KdsScale.bodySize * step,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      french ? line.nameFr : line.nameEn,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: KdsScale.bodySize * step,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (variant != null && variant.isNotEmpty)
                      Text(
                        variant,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    // ⚠ One line PER GROUP, not one joined sentence (Q69). Three
                    // groups run together with middots wrap across a card that is
                    // read at arm's length, and the answer a cook needs ends up on
                    // the second line of a grey run.
                    for (final String entry in options)
                      Text(
                        entry,
                        // ⚠ Keyed BY VALUE, not by a constant: two option rows in
                        // one column with the same key is a duplicate-key assertion
                        // that takes the whole board down, not a cosmetic warning.
                        key: Key('kds-line-option-$entry'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    if (removed.isNotEmpty)
                      Text(
                        removed.join(' · '),
                        key: const Key('kds-line-removed'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The quantity column's fixed width — the one thing on a ticket line that
  /// never gives way.
  static const double _quantityColumn = 44;

  /// The least room the dish name is left with before the picture goes.
  static const double _nameFloor = 72;

  /// Under this a thumbnail is a smudge, so it is omitted instead.
  static const double _thumbFloor = 32;
}
