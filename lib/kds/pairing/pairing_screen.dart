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
  bool _manual = false;

  @override
  void dispose() {
    _code.dispose();
    _host.dispose();
    super.dispose();
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
                    FilledButton.icon(
                      onPressed: pairing.searching ? null : controller.search,
                      icon: const Icon(Icons.wifi_find),
                      label: Text(
                        pairing.searching
                            ? l10n.kdsPairSearching
                            : l10n.kdsPairSearch,
                      ),
                    ),
                    const SizedBox(height: KdsScale.gapMd),
                    for (final HubAdvertisement hub in pairing.hubs)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.storefront_outlined),
                          title: Text(hub.hubLabel),
                          subtitle: Text(
                            '${hub.endpoint.host}:${hub.endpoint.port}',
                          ),
                          onTap: () => controller.select(hub),
                        ),
                      ),
                    const SizedBox(height: KdsScale.gapMd),
                    // The fallback the handbook documents, for a router with
                    // multicast switched off — which is most of them.
                    TextButton(
                      onPressed: () => setState(() => _manual = !_manual),
                      child: Text(l10n.kdsPairManual),
                    ),
                    if (_manual) ...<Widget>[
                      TextField(
                        controller: _host,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: l10n.kdsPairAddress,
                          hintText: '192.168.1.50:8801',
                        ),
                      ),
                      const SizedBox(height: KdsScale.gap),
                      OutlinedButton(
                        onPressed: () {
                          final List<String> parts = _host.text.trim().split(
                            ':',
                          );
                          final int port = parts.length > 1
                              ? (int.tryParse(parts[1]) ?? 8801)
                              : 8801;
                          if (parts.first.isNotEmpty) {
                            controller.findByAddress(parts.first, port);
                          }
                        },
                        child: Text(l10n.kdsPairConnect),
                      ),
                    ],
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
