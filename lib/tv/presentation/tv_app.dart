import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../../kds/theme/kds_theme.dart';
import '../state/tv_providers.dart';
import 'tv_screen.dart';

/// The dining-room TV app. One screen, no router (mirror of `KdsApp`).
class TvApp extends StatelessWidget {
  const TvApp({this.home, super.key});

  /// Pairing until this TV has an identity; the TV screen otherwise.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => AppLocalizations.of(context)!.tvTitle,
      debugShowCheckedModeBanner: false,
      locale: tvLocale,
      theme: KdsTheme.build(),
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home ?? const TvScreen(),
    );
  }
}
