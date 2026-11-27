import 'package:flutter/material.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../../tv/ports/tv_speech.dart';

/// « Sortie son » picker shared by both display surfaces' settings. The first
/// entry (null) is the Windows default output.
class OutputDropdown extends StatelessWidget {
  const OutputDropdown({
    required this.outputs,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });

  final List<TvAudioOutput> outputs;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool known = outputs.any((TvAudioOutput o) => o.id == selectedId);
    return DropdownButton<String?>(
      key: const ValueKey<String>('tv-output'),
      isExpanded: true,
      value: known ? selectedId : null,
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(child: Text(l10n.tvSettingsDefaultOutput)),
        for (final TvAudioOutput o in outputs)
          DropdownMenuItem<String?>(
            value: o.id,
            child: Text(o.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
