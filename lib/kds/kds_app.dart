import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import 'presentation/board_screen.dart';
import 'theme/kds_theme.dart';

/// The kitchen board app. One screen, no router: a cook never navigates.
class KdsApp extends StatelessWidget {
  const KdsApp({this.home, super.key});

  /// The view picker until a view is chosen; the board otherwise.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)!.kdsBoardTitle,
      debugShowCheckedModeBanner: false,
      // French, like the kiosk and for the same reason: the kitchen's language
      // is the restaurant's, not the tablet OS's.
      locale: const Locale('fr'),
      theme: KdsTheme.build(),
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home ?? const KdsBoardScreen(),
    );
  }
}
