import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import '../theme/kds_scale.dart';
import '../theme/kds_theme.dart';

/// Why the board cannot open for service.
enum KdsBootstrapState {
  /// No device identity in the store — a tablet out of the box, or one whose
  /// app data was cleared. It has not been paired with a kiosk hub, so it has
  /// no branch, no orders to show and no collection secret to verify slips
  /// against. Nothing here may be guessed.
  unpaired,
}

/// The board's own bootstrap surface, running *instead of* [KdsApp].
///
/// A kitchen tablet that force-unwrapped its identity died before `runApp` on a
/// fresh install, leaving a cook staring at a blank screen during service. This
/// says what is wrong, in French, at a size readable from across a kitchen.
class KdsBootstrapApp extends StatelessWidget {
  const KdsBootstrapApp({required this.state, super.key});

  final KdsBootstrapState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('fr'),
      debugShowCheckedModeBanner: false,
      theme: KdsTheme.build(),
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: KdsBootstrapScreen(state: state),
    );
  }
}

class KdsBootstrapScreen extends StatelessWidget {
  const KdsBootstrapScreen({required this.state, super.key});

  final KdsBootstrapState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        // Scrollable and width-capped on purpose. The French copy is longer than
        // the English, and at 1280×800 — a real kitchen tablet — the fixed
        // column overflowed by 14 px. Every French-string defect this project
        // has paid for was of exactly this shape, so the layout gives way
        // instead of the text.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KdsScale.gapLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.tablet_android_outlined,
                    size: 120,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: KdsScale.gapLg),
                  Text(
                    l10n.kdsUnpairedTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: KdsScale.headlineSize,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: KdsScale.gap),
                  Text(
                    l10n.kdsUnpairedBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: KdsScale.bodySize),
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
