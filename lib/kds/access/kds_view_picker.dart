import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import '../theme/kds_scale.dart';
import 'kds_view.dart';
import 'kds_view_controller.dart';

/// The first screen after pairing: two big buttons, « Cuisine » and
/// « Caisse paiement ». No login (owner, 2026-11-25).
class KdsViewPicker extends ConsumerWidget {
  const KdsViewPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final KdsViewController controller = ref.read(kdsViewProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KdsScale.gapLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.kdsViewPickerTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KdsScale.gapLg),
                  // Wrap, not Row: side by side on a landscape tablet, stacked
                  // on a narrow one — never clipped.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: KdsScale.gapLg,
                    runSpacing: KdsScale.gapLg,
                    children: <Widget>[
                      _Choice(
                        key: const Key('kds-view-kitchen'),
                        icon: Icons.restaurant,
                        label: l10n.kdsViewKitchen,
                        hint: l10n.kdsViewKitchenHint,
                        onTap: () => controller.choose(KdsView.kitchen),
                      ),
                      _Choice(
                        key: const Key('kds-view-cashier'),
                        icon: Icons.point_of_sale,
                        label: l10n.kdsViewCashier,
                        hint: l10n.kdsViewCashierHint,
                        onTap: () => controller.choose(KdsView.cashier),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 300,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(300, 180),
          padding: const EdgeInsets.all(KdsScale.gapLg),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56),
            const SizedBox(height: KdsScale.gapMd),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: KdsScale.gap),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
