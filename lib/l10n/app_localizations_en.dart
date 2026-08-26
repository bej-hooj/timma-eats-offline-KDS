// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get kdsBoardTitle => 'Kitchen';

  @override
  String get kdsLaneCounter => 'To collect';

  @override
  String get kdsLaneScheduled => 'Scheduled';

  @override
  String get kdsLaneNew => 'New';

  @override
  String get kdsLanePreparing => 'Preparing';

  @override
  String get kdsLaneReady => 'Ready';

  @override
  String get kdsLaneOutForDelivery => 'Out for delivery';

  @override
  String get kdsLaneEmpty => 'Nothing here';

  @override
  String get kdsSettleCash => 'Take cash';

  @override
  String get kdsAccept => 'Accept';

  @override
  String get kdsStartPreparing => 'Start';

  @override
  String get kdsMarkReady => 'Ready';

  @override
  String get kdsHandOver => 'Hand over';

  @override
  String get kdsSendOut => 'Send out';

  @override
  String get kdsComplete => 'Complete';

  @override
  String get kdsPaid => 'Paid';

  @override
  String get kdsUnpaid => 'To collect';

  @override
  String get kdsSourceKiosk => 'Kiosk';

  @override
  String get kdsSourceApp => 'App';

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
  String get kdsUnpairedTitle => 'Tablet not paired';

  @override
  String get kdsUnpairedBody =>
      'This tablet is not paired with a kiosk yet. Ask the manager to pair it before service.';

  @override
  String get kdsOffline => 'Offline';

  @override
  String get kdsMuteAlarm => 'Mute alarm';

  @override
  String get kdsAlarmMuted => 'Alarm muted';

  @override
  String kdsExpired(int count) {
    return '$count unpaid ticket(s) expired';
  }

  @override
  String get kdsPairTitle => 'Pair this kitchen';

  @override
  String get kdsPairSubtitle =>
      'Find the kiosk on the restaurant wifi, then type the code shown on its screen.';

  @override
  String get kdsPairSearch => 'Find the kiosk';

  @override
  String get kdsPairSearching => 'Searching…';

  @override
  String get kdsPairManual => 'Type the address by hand';

  @override
  String get kdsPairAddress => 'Kiosk address';

  @override
  String get kdsPairConnect => 'Connect';

  @override
  String get kdsPairChange => 'Change';

  @override
  String get kdsPairCodePrompt => 'Type the six digits shown on the kiosk.';

  @override
  String get kdsPairJoin => 'Pair';

  @override
  String get kdsPairJoining => 'Pairing…';

  @override
  String get kdsPairErrorCode =>
      'Code refused. Check the six digits, or ask the kiosk for a new one.';

  @override
  String get kdsPairErrorExpired =>
      'Code expired. Ask the kiosk for a new one.';

  @override
  String get kdsPairErrorNotFound =>
      'No kiosk found. Check both devices are on the same wifi.';

  @override
  String get kdsPairErrorUnreachable =>
      'Kiosk unreachable. Check the wifi and the address.';

  @override
  String get kdsPairErrorStore =>
      'This tablet could not store the security key.';

  @override
  String get kdsRepairTitle => 'Pair with another kiosk';

  @override
  String get kdsRepairBody =>
      'This kitchen will stop receiving orders from the current kiosk. You will need to enter a new pairing code.';

  @override
  String get kdsRepairCancel => 'Cancel';

  @override
  String get kdsRepairConfirm => 'Pair again';

  @override
  String kdsWithout(String ingredient) {
    return 'NO $ingredient';
  }
}
