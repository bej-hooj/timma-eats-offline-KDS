import 'package:flutter/material.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../../tv/ports/tv_speech.dart';

/// « Écran » picker shared by both display surfaces' settings. The first entry
/// (null) is « Automatique » — the surface's native default monitor.
class MonitorDropdown extends StatelessWidget {
  const MonitorDropdown({
    required this.monitors,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });

  final List<TvMonitor> monitors;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool known = monitors.any((TvMonitor m) => m.id == selectedId);
    return DropdownButton<String?>(
      key: const ValueKey<String>('display-monitor'),
      isExpanded: true,
      value: known ? selectedId : null,
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(
          child: Text(l10n.displaySettingsDefaultMonitor),
        ),
        for (final TvMonitor m in monitors)
          DropdownMenuItem<String?>(
            value: m.id,
            child: Text(
              '${m.name} — ${m.width} × ${m.height}'
              '${m.isPrimary ? ' ${l10n.displaySettingsMainMonitorSuffix}' : ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
