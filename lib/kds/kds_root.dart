import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_core/pos_core.dart';

import 'package:timma_kds/l10n/app_localizations.dart';
import 'kds_app.dart';
import 'pairing/pairing_screen.dart';
import 'state/kds_board.dart';
import 'theme/kds_theme.dart';

/// Chooses between pairing and the board, and switches the moment pairing wins.
///
/// This exists because the board used to be decided **once, in `main`**: an
/// unpaired tablet got a dead-end screen and the only way past it was to
/// reinstall. Now the identity lives in a provider, so the tablet a manager
/// just paired drops straight into service without anyone restarting anything.
class KdsRoot extends ConsumerWidget {
  const KdsRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PosDeviceIdentity? identity = ref.watch(kdsIdentityProvider);
    if (identity == null) {
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
        home: const KdsPairingScreen(),
      );
    }

    // The engine derives from this identity, so there is no window in which a
    // screen could read it without a branch.
    return const KdsApp();
  }
}
