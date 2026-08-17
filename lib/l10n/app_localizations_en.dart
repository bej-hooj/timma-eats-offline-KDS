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
  String get kdsOffline => 'Offline';

  @override
  String get kdsMuteAlarm => 'Mute alarm';

  @override
  String get kdsAlarmMuted => 'Alarm muted';

  @override
  String kdsExpired(int count) {
    return '$count unpaid ticket(s) expired';
  }
}
