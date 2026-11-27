import 'package:flutter/material.dart';

import 'package:timma_kds/design/time_util.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import '../tv_palette.dart';

/// Wordmark, the time in Douala, and an offline badge when the borne is gone.
/// A double-tap on the clock opens the settings (the mouse route; F2 is the
/// keyboard one).
class TvHeader extends StatelessWidget {
  const TvHeader({
    required this.now,
    required this.connected,
    required this.onOpenSettings,
    super.key,
  });

  final DateTime now;
  final bool connected;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double h = box.maxHeight;
        return ColoredBox(
          color: TvPalette.header,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: h * 0.4),
            child: Row(
              children: <Widget>[
                Image.asset(
                  'assets/branding/logo_inline.png',
                  height: h * 0.55,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext _, Object _, StackTrace? _) => const SizedBox.shrink(),
                ),
                const Spacer(),
                if (!connected)
                  Container(
                    key: const ValueKey<String>('tv-offline'),
                    margin: EdgeInsets.only(right: h * 0.3),
                    padding: EdgeInsets.symmetric(horizontal: h * 0.2, vertical: h * 0.06),
                    decoration: BoxDecoration(
                      color: TvPalette.offline,
                      borderRadius: BorderRadius.circular(h * 0.2),
                    ),
                    child: Text(
                      l10n.tvOffline,
                      style: TextStyle(color: TvPalette.onOffline, fontSize: h * 0.25, fontWeight: FontWeight.w700),
                    ),
                  ),
                GestureDetector(
                  key: const ValueKey<String>('tv-clock'),
                  onDoubleTap: onOpenSettings,
                  onLongPress: onOpenSettings,
                  child: Text(
                    TimeUtil.formatTime(now, locale: 'fr'),
                    style: TextStyle(color: TvPalette.onHeader, fontSize: h * 0.42, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
