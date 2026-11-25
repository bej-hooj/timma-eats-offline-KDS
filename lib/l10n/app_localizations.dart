import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Collapsed ticket summary: how many dishes are on it.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun article} =1{1 article} other{{count} articles}}'**
  String kdsItems(int count);

  /// No description provided for @kdsBoardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Cuisine'**
  String get kdsBoardTitle;

  /// No description provided for @kdsLaneCounter.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser'**
  String get kdsLaneCounter;

  /// No description provided for @kdsLaneScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Programmées'**
  String get kdsLaneScheduled;

  /// No description provided for @kdsLaneNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelles'**
  String get kdsLaneNew;

  /// No description provided for @kdsLanePreparing.
  ///
  /// In fr, this message translates to:
  /// **'En préparation'**
  String get kdsLanePreparing;

  /// No description provided for @kdsLaneReady.
  ///
  /// In fr, this message translates to:
  /// **'Prêtes'**
  String get kdsLaneReady;

  /// No description provided for @kdsLaneOutForDelivery.
  ///
  /// In fr, this message translates to:
  /// **'En livraison'**
  String get kdsLaneOutForDelivery;

  /// A ticket older than a few hours: hours, not an unreadable minute count.
  ///
  /// In fr, this message translates to:
  /// **'+{hours} h'**
  String kdsWaitingLong(int hours);

  /// A ticket whose lines have not reached this board.
  ///
  /// In fr, this message translates to:
  /// **'Détail non reçu'**
  String get kdsLinesPending;

  /// No description provided for @kdsLaneEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Rien ici'**
  String get kdsLaneEmpty;

  /// No description provided for @kdsSettleCash.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser en espèces'**
  String get kdsSettleCash;

  /// No description provided for @kdsAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get kdsAccept;

  /// No description provided for @kdsStartPreparing.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get kdsStartPreparing;

  /// No description provided for @kdsMarkReady.
  ///
  /// In fr, this message translates to:
  /// **'Prêt'**
  String get kdsMarkReady;

  /// No description provided for @kdsHandOver.
  ///
  /// In fr, this message translates to:
  /// **'Remettre'**
  String get kdsHandOver;

  /// No description provided for @kdsSendOut.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer en livraison'**
  String get kdsSendOut;

  /// No description provided for @kdsComplete.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get kdsComplete;

  /// No description provided for @kdsPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payé'**
  String get kdsPaid;

  /// No description provided for @kdsUnpaid.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser'**
  String get kdsUnpaid;

  /// No description provided for @kdsSourceKiosk.
  ///
  /// In fr, this message translates to:
  /// **'Borne'**
  String get kdsSourceKiosk;

  /// No description provided for @kdsSourceApp.
  ///
  /// In fr, this message translates to:
  /// **'Appli'**
  String get kdsSourceApp;

  /// No description provided for @kdsSourceWeb.
  ///
  /// In fr, this message translates to:
  /// **'Web'**
  String get kdsSourceWeb;

  /// No description provided for @kdsWaitingMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String kdsWaitingMinutes(int minutes);

  /// The station-qualified ticket, e.g. B1-07. A String, not an int: two bornes both count from 1, so the number alone stopped identifying an order the moment a branch had a second till.
  ///
  /// In fr, this message translates to:
  /// **'Ticket {label}'**
  String kdsTicket(String label);

  /// No description provided for @kdsUnpairedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tablette non appariée'**
  String get kdsUnpairedTitle;

  /// No description provided for @kdsUnpairedBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette tablette n\'est pas encore appariée à une borne. Contactez le responsable pour l\'apparier avant le service.'**
  String get kdsUnpairedBody;

  /// No description provided for @kdsOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get kdsOffline;

  /// No description provided for @kdsMuteAlarm.
  ///
  /// In fr, this message translates to:
  /// **'Couper l\'alarme'**
  String get kdsMuteAlarm;

  /// No description provided for @kdsAlarmMuted.
  ///
  /// In fr, this message translates to:
  /// **'Alarme coupée'**
  String get kdsAlarmMuted;

  /// No description provided for @kdsPairTitle.
  ///
  /// In fr, this message translates to:
  /// **'Apparier cette cuisine'**
  String get kdsPairTitle;

  /// No description provided for @kdsPairSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la borne sur le wifi du restaurant, puis validez sur son écran.'**
  String get kdsPairSubtitle;

  /// No description provided for @kdsPairSearch.
  ///
  /// In fr, this message translates to:
  /// **'Chercher la borne'**
  String get kdsPairSearch;

  /// No description provided for @kdsPairSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche en cours…'**
  String get kdsPairSearching;

  /// No description provided for @kdsPairManual.
  ///
  /// In fr, this message translates to:
  /// **'Saisir l\'adresse à la main'**
  String get kdsPairManual;

  /// No description provided for @kdsPairAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse de la borne'**
  String get kdsPairAddress;

  /// No description provided for @kdsPairConnect.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get kdsPairConnect;

  /// No description provided for @kdsPairChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get kdsPairChange;

  /// No description provided for @kdsPairCodePrompt.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez les six chiffres affichés sur la borne.'**
  String get kdsPairCodePrompt;

  /// No description provided for @kdsPairJoin.
  ///
  /// In fr, this message translates to:
  /// **'Apparier'**
  String get kdsPairJoin;

  /// No description provided for @kdsPairJoining.
  ///
  /// In fr, this message translates to:
  /// **'Appairage…'**
  String get kdsPairJoining;

  /// No description provided for @kdsPairErrorCode.
  ///
  /// In fr, this message translates to:
  /// **'Code refusé. Vérifiez les six chiffres, ou demandez-en un nouveau sur la borne.'**
  String get kdsPairErrorCode;

  /// No description provided for @kdsPairErrorExpired.
  ///
  /// In fr, this message translates to:
  /// **'Code expiré. Demandez-en un nouveau sur la borne.'**
  String get kdsPairErrorExpired;

  /// No description provided for @kdsPairErrorNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune borne trouvée. Vérifiez que les deux appareils sont sur le même wifi.'**
  String get kdsPairErrorNotFound;

  /// No description provided for @kdsPairErrorUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Borne injoignable. Vérifiez le wifi et l\'adresse.'**
  String get kdsPairErrorUnreachable;

  /// No description provided for @kdsPairErrorStore.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer la clé de sécurité sur cette tablette.'**
  String get kdsPairErrorStore;

  /// No description provided for @kdsRepairTitle.
  ///
  /// In fr, this message translates to:
  /// **'Apparier une autre borne'**
  String get kdsRepairTitle;

  /// No description provided for @kdsRepairBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette cuisine ne recevra plus les commandes de la borne actuelle. Vous devrez l\'apparier à nouveau.'**
  String get kdsRepairBody;

  /// No description provided for @kdsRepairCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get kdsRepairCancel;

  /// No description provided for @kdsRepairConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Apparier à nouveau'**
  String get kdsRepairConfirm;

  /// No description provided for @kdsWithout.
  ///
  /// In fr, this message translates to:
  /// **'SANS {ingredient}'**
  String kdsWithout(String ingredient);

  /// Q69 — une ligne de composition sur un ticket cuisine. Les deux-points prennent une espace avant en français, d'où le motif ici et pas dans le code.
  ///
  /// In fr, this message translates to:
  /// **'{group} : {answer}'**
  String kdsGroupLabel(String group, String answer);

  /// Q69 — la réponse « rien choisi » pour un groupe QUI A ÉTÉ PROPOSÉ. En capitales comme SANS : c'est une instruction que le cuisinier doit lire de loin, et ne rien imprimer serait indiscernable d'un plat qui n'a jamais posé la question.
  ///
  /// In fr, this message translates to:
  /// **'AUCUN'**
  String get kdsGroupNone;

  /// No description provided for @kdsPairTap.
  ///
  /// In fr, this message translates to:
  /// **'Apparier en un geste'**
  String get kdsPairTap;

  /// No description provided for @kdsPairWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Validez sur la borne'**
  String get kdsPairWaiting;

  /// No description provided for @kdsPairCompare.
  ///
  /// In fr, this message translates to:
  /// **'Ce nombre doit être le même sur l\'écran de la borne.'**
  String get kdsPairCompare;

  /// No description provided for @kdsPairOrCode.
  ///
  /// In fr, this message translates to:
  /// **'Ou saisissez le code affiché sur la borne'**
  String get kdsPairOrCode;

  /// No description provided for @kdsPairErrorRefused.
  ///
  /// In fr, this message translates to:
  /// **'La borne a refusé cette cuisine.'**
  String get kdsPairErrorRefused;

  /// No description provided for @kdsDeleteTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le ticket'**
  String get kdsDeleteTooltip;

  /// No description provided for @kdsDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le ticket {ticket} ?'**
  String kdsDeleteTitle(String ticket);

  /// No description provided for @kdsDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'La commande sera annulée. Le client n\'a pas payé.'**
  String get kdsDeleteBody;

  /// No description provided for @kdsDeleteCancel.
  ///
  /// In fr, this message translates to:
  /// **'Garder'**
  String get kdsDeleteCancel;

  /// No description provided for @kdsDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get kdsDeleteConfirm;

  /// No description provided for @kdsViewPickerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quelle vue pour cette tablette ?'**
  String get kdsViewPickerTitle;

  /// No description provided for @kdsViewKitchen.
  ///
  /// In fr, this message translates to:
  /// **'Cuisine'**
  String get kdsViewKitchen;

  /// No description provided for @kdsViewKitchenHint.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelles → En préparation → Prêtes'**
  String get kdsViewKitchenHint;

  /// No description provided for @kdsViewCashier.
  ///
  /// In fr, this message translates to:
  /// **'Caisse paiement'**
  String get kdsViewCashier;

  /// No description provided for @kdsViewCashierHint.
  ///
  /// In fr, this message translates to:
  /// **'Tickets borne à encaisser'**
  String get kdsViewCashierHint;

  /// No description provided for @kdsSwitchView.
  ///
  /// In fr, this message translates to:
  /// **'Changer de vue'**
  String get kdsSwitchView;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
