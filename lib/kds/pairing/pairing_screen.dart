import 'package:flutter/material.dart';
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
                  const SizedBox(height: KdsScale.gap),
                  Text(
                    l10n.kdsPairSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: KdsScale.bodySize),
                  ),
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
                    Text(
                      l10n.kdsPairCodePrompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: KdsScale.bodySize),
                    ),
                    const SizedBox(height: KdsScale.gap),
                    TextField(
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
                      decoration: const InputDecoration(counterText: ''),
                    ),
                    const SizedBox(height: KdsScale.gapMd),
                    FilledButton(
                      onPressed: pairing.joining || _code.text.length < 6
                          ? null
                          : () => controller.join(_code.text),
                      child: Text(
                        pairing.joining
                            ? l10n.kdsPairJoining
                            : l10n.kdsPairJoin,
                      ),
                    ),
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
