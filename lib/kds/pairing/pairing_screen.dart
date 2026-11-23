import 'package:flutter/material.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_link/pos_link.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../theme/kds_scale.dart';
import 'pairing_controller.dart';

/// Joining a kiosk: find it, then type the six digits it is showing.
///
/// The board is unpaired until this succeeds, and it says so plainly rather
/// than pretending to be a board with no orders — an empty kitchen screen and a
/// disconnected one look identical, and only one of them needs a manager.
class KdsPairingScreen extends ConsumerStatefulWidget {
  const KdsPairingScreen({super.key});

  @override
  ConsumerState<KdsPairingScreen> createState() => _KdsPairingScreenState();
}

class _KdsPairingScreenState extends ConsumerState<KdsPairingScreen> {
  final TextEditingController _code = TextEditingController();

  /// Whether the six-digit fallback is on screen. Off by default: tapping is
  /// the first procedure now, the code is the second.
  bool _showCode = false;
  final TextEditingController _host = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _host.dispose();
    super.dispose();
  }

  void _connectByAddress() {
    final List<String> parts = _host.text.trim().split(':');
    if (parts.first.isEmpty) {
      return;
    }
    final int port = parts.length > 1 ? (int.tryParse(parts[1]) ?? 8801) : 8801;
    ref.read(kdsPairingProvider.notifier).findByAddress(parts.first, port);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final KdsPairingState pairing = ref.watch(kdsPairingProvider);
    final KdsPairingController controller = ref.read(
      kdsPairingProvider.notifier,
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KdsScale.gapLg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.kdsPairTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: KdsScale.headlineSize,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  // ⚠ Only while it is still instructions. Once a kiosk has
                  // been chosen this sentence describes a step already taken,
                  // and its two lines are two lines the ACTION needs: at
                  // 844 x 390 — the board in landscape — the whole code step
                  // ran past the bottom of the screen and *Apparier* could not
                  // be reached or scrolled to. Pairing was impossible from the
                  // product on the one device shape it ships on.
                  if (pairing.selected == null) ...<Widget>[
                    const SizedBox(height: KdsScale.gap),
                    Text(
                      l10n.kdsPairSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: KdsScale.bodySize),
                    ),
                  ],
                  const SizedBox(height: KdsScale.gapLg),

                  if (pairing.selected == null) ...<Widget>[
                    // ⚠ Both ways in are on screen at once, and side by side on
                    // a wide screen. The manual address used to hide behind a
                    // toggle at the bottom of a scroll: on a phone-sized board
                    // in landscape that put the handbook's documented fallback
                    // BELOW THE FOLD, so a manager on a router with multicast
                    // disabled saw only a search that finds nothing. The
                    // fallback for the common case must not need a scroll.
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final Widget search = _SearchColumn(
                              searching: pairing.searching,
                              hubs: pairing.hubs,
                              onSearch: controller.search,
                              onSelect: controller.select,
                            );
                            final Widget manual = _ManualColumn(
                              controller: _host,
                              onConnect: _connectByAddress,
                            );
                            // Landscape on a phone is ~850 × 390: wide and
                            // short, so the two options go across rather than
                            // down.
                            if (constraints.maxWidth >= 700) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(child: search),
                                  const SizedBox(width: KdsScale.gapLg),
                                  Expanded(child: manual),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                search,
                                const SizedBox(height: KdsScale.gapLg),
                                manual,
                              ],
                            );
                          },
                    ),
                  ] else ...<Widget>[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.storefront),
                        title: Text(pairing.selected!.hubLabel),
                        subtitle: Text(
                          '${pairing.selected!.endpoint.host}:'
                          '${pairing.selected!.endpoint.port}',
                        ),
                        trailing: TextButton(
                          onPressed: controller.deselect,
                          child: Text(l10n.kdsPairChange),
                        ),
                      ),
                    ),
                    const SizedBox(height: KdsScale.gapMd),
                    // ⚠⚠ The one-tap path comes FIRST and the code second.
                    // Owner, 2026-11-22: *"the code is always bothering"*. A
                    // cook who sees a keypad reaches for it.
                    if (pairing.awaitingApproval != null)
                      _WaitingForApproval(digits: pairing.awaitingApproval!)
                    else
                      SizedBox(
                        height: KdsScale.minTarget,
                        child: FilledButton.icon(
                          onPressed: pairing.joining
                              ? null
                              : () => controller.join(),
                          icon: const Icon(Icons.touch_app_outlined),
                          label: Text(
                            pairing.joining
                                ? l10n.kdsPairJoining
                                : l10n.kdsPairTap,
                          ),
                        ),
                      ),
                    const SizedBox(height: KdsScale.gapMd),
                    // ⚠ The code path is REVEALED, not shown. A landscape
                    // board is 390 dp tall and the two paths together ran the
                    // *Apparier* button 53 px off the bottom — caught by the
                    // test that has guarded this screen since August. Hiding
                    // it is also the honest hierarchy: the owner asked for the
                    // code to stop being the first thing a cook sees.
                    if (!_showCode)
                      TextButton(
                        onPressed: () => setState(() => _showCode = true),
                        child: Text(l10n.kdsPairOrCode),
                      ),
                    if (_showCode) ...<Widget>[
                      Text(
                        l10n.kdsPairCodePrompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: KdsScale.labelSize,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: KdsScale.gap),
                      // ⚠ `ValueListenableBuilder`, not a bare read of
                      // `_code.text`.
                      //
                      // The button's enabled state depends on what has been
                      // typed, and this screen only rebuilt when the PAIRING
                      // state changed — so typing all six digits left the button
                      // disabled and pairing was impossible from the product.
                      // Reported from the device; a widget test now types the
                      // digits and asserts the button comes alive.
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _code,
                        builder:
                            (
                              BuildContext context,
                              TextEditingValue value,
                              Widget? _,
                            ) {
                              final bool complete = value.text.length == 6;
                              // The field and the button side by side, not
                              // stacked: a landscape board is wide and short, and
                              // stacking them is what pushed the action off the
                              // bottom.
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Expanded(
                                    child: TextField(
                                      controller: _code,
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: <TextInputFormatter>[
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6),
                                      ],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: KdsScale.totalSize,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 8,
                                      ),
                                      decoration: const InputDecoration(
                                        counterText: '',
                                      ),
                                      // A six-digit code has one obvious end, and a
                                      // cook holding a tablet should not have to
                                      // find a button after typing it.
                                      onSubmitted: (String code) {
                                        if (code.length == 6) {
                                          controller.join(code);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: KdsScale.gapMd),
                                  FilledButton(
                                    // Sized for a Row: the theme's button
                                    // minimum is `Size.fromHeight`, which is an
                                    // infinite width and an unbounded-width
                                    // crash here.
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(
                                        0,
                                        KdsScale.minTarget,
                                      ),
                                    ),
                                    onPressed: pairing.joining || !complete
                                        ? null
                                        : () => controller.join(value.text),
                                    child: Text(
                                      pairing.joining
                                          ? l10n.kdsPairJoining
                                          : l10n.kdsPairJoin,
                                    ),
                                  ),
                                ],
                              );
                            },
                      ),
                    ],
                  ],

                  if (pairing.error != null) ...<Widget>[
                    const SizedBox(height: KdsScale.gapMd),
                    Text(
                      _errorText(l10n, pairing.error!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: KdsScale.bodySize,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
    KdsPairingError.badCode => l10n.kdsPairErrorCode,
    KdsPairingError.expired => l10n.kdsPairErrorExpired,
    KdsPairingError.notFound => l10n.kdsPairErrorNotFound,
    KdsPairingError.storeFailed => l10n.kdsPairErrorStore,
    _ => l10n.kdsPairErrorUnreachable,
  };
}

/// Discovery: one button and whatever answered.
class _SearchColumn extends StatelessWidget {
  const _SearchColumn({
    required this.searching,
    required this.hubs,
    required this.onSearch,
    required this.onSelect,
  });

  final bool searching;
  final List<HubAdvertisement> hubs;
  final VoidCallback onSearch;
  final void Function(HubAdvertisement hub) onSelect;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: searching ? null : onSearch,
          icon: const Icon(Icons.wifi_find),
          label: Text(searching ? l10n.kdsPairSearching : l10n.kdsPairSearch),
        ),
        for (final HubAdvertisement hub in hubs) ...<Widget>[
          const SizedBox(height: KdsScale.gap),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(hub.hubLabel),
              subtitle: Text('${hub.endpoint.host}:${hub.endpoint.port}'),
              onTap: () => onSelect(hub),
            ),
          ),
        ],
      ],
    );
  }
}

/// The address a manager reads off the kiosk's own manager screen.
class _ManualColumn extends StatelessWidget {
  const _ManualColumn({required this.controller, required this.onConnect});

  final TextEditingController controller;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.kdsPairManual,
          style: const TextStyle(
            fontSize: KdsScale.labelSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: KdsScale.gap),
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.kdsPairAddress,
            hintText: '192.168.1.50:8801',
          ),
          onSubmitted: (_) => onConnect(),
        ),
        const SizedBox(height: KdsScale.gap),
        OutlinedButton(onPressed: onConnect, child: Text(l10n.kdsPairConnect)),
      ],
    );
  }
}

/// What the cook looks at while someone walks to the borne.
///
/// ⚠ The number is **to compare, never to type**. It is the out-of-band
/// channel that authenticates a key agreement carrying no code: a man in the
/// middle would have to run two of them, and the two screens would differ.
class _WaitingForApproval extends StatelessWidget {
  const _WaitingForApproval({required this.digits});

  final String digits;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      children: <Widget>[
        Text(
          l10n.kdsPairWaiting,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: KdsScale.bodySize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: KdsScale.gap),
        Text(
          _spaced(digits),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: KdsScale.totalSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: KdsScale.gap),
        Text(
          l10n.kdsPairCompare,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: KdsScale.labelSize,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  static String _spaced(String digits) {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 2 == 0) {
        out.write('\u2009');
      }
      out.write(digits[i]);
    }
    return out.toString();
  }
}
