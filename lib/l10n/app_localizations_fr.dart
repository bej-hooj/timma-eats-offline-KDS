// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get kdsBoardTitle => 'Cuisine';

  @override
  String get kdsLaneCounter => 'À encaisser';

  @override
  String get kdsLaneScheduled => 'Programmées';

  @override
  String get kdsLaneNew => 'Nouvelles';

  @override
  String get kdsLanePreparing => 'En préparation';

  @override
  String get kdsLaneReady => 'Prêtes';

  @override
  String get kdsLaneOutForDelivery => 'En livraison';

  @override
  String get kdsLaneEmpty => 'Rien ici';

  @override
  String get kdsSettleCash => 'Encaisser en espèces';

  @override
  String get kdsAccept => 'Accepter';

  @override
  String get kdsStartPreparing => 'Commencer';

  @override
  String get kdsMarkReady => 'Prêt';

  @override
  String get kdsHandOver => 'Remettre';

  @override
  String get kdsSendOut => 'Envoyer en livraison';

  @override
  String get kdsComplete => 'Terminer';

  @override
  String get kdsPaid => 'Payé';

  @override
  String get kdsUnpaid => 'À encaisser';

  @override
  String get kdsSourceKiosk => 'Borne';

  @override
  String get kdsSourceApp => 'Appli';

  @override
  String get kdsSourceWeb => 'Web';

  @override
  String kdsWaitingMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String kdsTicket(int number) {
    return 'Ticket $number';
  }

  @override
  String get kdsUnpairedTitle => 'Tablette non appariée';

  @override
  String get kdsUnpairedBody =>
      'Cette tablette n\'est pas encore appariée à une borne. Contactez le responsable pour l\'apparier avant le service.';

  @override
  String get kdsOffline => 'Hors ligne';

  @override
  String get kdsMuteAlarm => 'Couper l\'alarme';

  @override
  String get kdsAlarmMuted => 'Alarme coupée';

  @override
  String kdsExpired(int count) {
    return '$count ticket(s) non payé(s) expiré(s)';
  }

  @override
  String get kdsPairTitle => 'Apparier cette cuisine';

  @override
  String get kdsPairSubtitle =>
      'Trouvez la borne sur le wifi du restaurant, puis saisissez le code affiché sur son écran.';

  @override
  String get kdsPairSearch => 'Chercher la borne';

  @override
  String get kdsPairSearching => 'Recherche en cours…';

  @override
  String get kdsPairManual => 'Saisir l\'adresse à la main';

  @override
  String get kdsPairAddress => 'Adresse de la borne';

  @override
  String get kdsPairConnect => 'Se connecter';

  @override
  String get kdsPairChange => 'Changer';

  @override
  String get kdsPairCodePrompt =>
      'Saisissez les six chiffres affichés sur la borne.';

  @override
  String get kdsPairJoin => 'Apparier';

  @override
  String get kdsPairJoining => 'Appairage…';

  @override
  String get kdsPairErrorCode => 'Code refusé. Vérifiez les six chiffres.';

  @override
  String get kdsPairErrorExpired =>
      'Code expiré. Demandez-en un nouveau sur la borne.';

  @override
  String get kdsPairErrorNotFound =>
      'Aucune borne trouvée. Vérifiez que les deux appareils sont sur le même wifi.';

  @override
  String get kdsPairErrorUnreachable =>
      'Borne injoignable. Vérifiez le wifi et l\'adresse.';

  @override
  String get kdsPairErrorStore =>
      'Impossible d\'enregistrer la clé de sécurité sur cette tablette.';
}
