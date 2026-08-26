import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/design/money_formatter.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import '../../domain/kds_lanes.dart';
import '../../theme/kds_scale.dart';

/// One ticket, carrying its identity (ECOSYSTEM §1.6).
///
/// **Every card states its `source` and its money state**, because *take cash*
/// and *already paid* must never be confusable — a cook who reads one as the
/// other either hands out free food or asks a customer to pay twice. A
/// paid-online ticket enters the cook lane directly and never shows a cash
/// button at all.
class KdsTicketCard extends StatelessWidget {
  const KdsTicketCard({
    required this.order,
    required this.lines,
    required this.now,
    required this.onPrimaryAction,
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final KdsUrgency urgency = KdsSla.urgencyOf(order, now);
    final int waited = now.difference(KdsSla.agedFrom(order)).inMinutes;
    final bool paid = order.paymentStatus == PosPaymentStatus.paid;
    final bool french = Localizations.localeOf(context).languageCode == 'fr';

    return Card(
      margin: const EdgeInsets.only(bottom: KdsScale.gapMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KdsScale.radius),
        // Urgency is a border, not a fill: a red-filled card at 20 minutes
        // makes its own text harder to read exactly when it matters most.
        side: BorderSide(color: _urgencyColor(theme, urgency), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KdsScale.gapMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
                Text(
                  l10n.kdsWaitingMinutes(waited),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _urgencyColor(theme, urgency),
                    fontWeight: FontWeight.w700,
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
            if (order.ticketLabelOrNull != null)
              Text(
                l10n.kdsTicket(order.ticketLabelOrNull!),
                style: theme.textTheme.titleLarge,
              ),
            if (lines.isNotEmpty) ...<Widget>[
              const SizedBox(height: KdsScale.gapMd),
              for (final PosOrderLine line in lines)
                _Line(line: line, french: french, l10n: l10n),
            ],
            if (order.note != null &&
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
            const SizedBox(height: KdsScale.gap),
            Text(
              MoneyFormatter.formatXaf(order.total),
              style: const TextStyle(
                fontSize: KdsScale.totalSize,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            if (onPrimaryAction != null) ...<Widget>[
              const SizedBox(height: KdsScale.gapMd),
              SizedBox(
                width: double.infinity,
                height: KdsScale.minTarget,
                child: FilledButton(
                  onPressed: onPrimaryAction,
                  child: Text(_actionLabel(l10n, order)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
  const _Line({required this.line, required this.french, required this.l10n});

  final PosOrderLine line;
  final bool french;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? variant = french ? line.variantNameFr : line.variantNameEn;
    final List<String> options = <String>[
      for (final PosLineModifier m in line.modifiers)
        m.quantity > 1
            ? '${m.quantity} × ${french ? m.nameFr : m.nameEn}'
            : (french ? m.nameFr : m.nameEn),
    ];
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(
              '${line.quantity} ×',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: KdsScale.bodySize,
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
                    fontSize: KdsScale.bodySize,
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
                if (options.isNotEmpty)
                  Text(
                    options.join(' · '),
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
      ),
    );
  }
}
