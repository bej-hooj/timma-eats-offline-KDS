import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'package:timma_kds/l10n/app_localizations.dart';
import 'presentation/board_screen.dart';
import 'theme/kds_scale.dart';

/// The kitchen board app. One screen, no router: a cook never navigates.
class KdsApp extends StatelessWidget {
  const KdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)!.kdsBoardTitle,
      debugShowCheckedModeBanner: false,
      // French, like the kiosk and for the same reason: the kitchen's language
      // is the restaurant's, not the tablet OS's.
      locale: const Locale('fr'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          error: AppColors.error,
          outline: AppColors.outline,
        ),
        scaffoldBackgroundColor: AppColors.canvas,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(KdsScale.minTarget),
            textStyle: const TextStyle(
              fontSize: KdsScale.bodySize,
              fontWeight: FontWeight.w700,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(KdsScale.radius)),
            ),
          ),
        ),
      ),
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const KdsBoardScreen(),
    );
  }
}
