// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String kdsItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
      zero: 'aucun article',
    );
    return '$_temp0';
  }

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
  String kdsWaitingLong(int hours) {
    return '+$hours h';
  }

  @override
  String get kdsLinesPending => 'Détail non reçu';

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
  String kdsTicket(String label) {
    return 'Ticket $label';
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
  String get kdsPairTitle => 'Apparier cette cuisine';

  @override
  String get kdsPairSubtitle =>
      'Choisissez la borne sur le wifi du restaurant, puis validez sur son écran.';

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
  String get kdsPairErrorCode =>
      'Code refusé. Vérifiez les six chiffres, ou demandez-en un nouveau sur la borne.';

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

  @override
  String get kdsRepairTitle => 'Apparier une autre borne';

  @override
  String get kdsRepairBody =>
      'Cette cuisine ne recevra plus les commandes de la borne actuelle. Vous devrez l\'apparier à nouveau.';

  @override
  String get kdsRepairCancel => 'Annuler';

  @override
  String get kdsRepairConfirm => 'Apparier à nouveau';

  @override
  String kdsWithout(String ingredient) {
    return 'SANS $ingredient';
  }

  @override
  String kdsGroupLabel(String group, String answer) {
    return '$group : $answer';
  }

  @override
  String get kdsGroupNone => 'AUCUN';

  @override
  String get kdsPairTap => 'Apparier en un geste';

  @override
  String get kdsPairWaiting => 'Validez sur la borne';

  @override
  String get kdsPairCompare =>
      'Ce nombre doit être le même sur l\'écran de la borne.';

  @override
  String get kdsPairOrCode => 'Ou saisissez le code affiché sur la borne';

  @override
  String get kdsPairErrorRefused => 'La borne a refusé cette cuisine.';

  @override
  String get kdsDeleteTooltip => 'Supprimer le ticket';

  @override
  String kdsDeleteTitle(String ticket) {
    return 'Supprimer le ticket $ticket ?';
  }

  @override
  String get kdsDeleteBody =>
      'La commande sera annulée. Le client n\'a pas payé.';

  @override
  String get kdsDeleteCancel => 'Garder';

  @override
  String get kdsDeleteConfirm => 'Supprimer';
}
