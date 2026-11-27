// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String kdsItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'no items',
    );
    return '$_temp0';
  }

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
  String kdsWaitingLong(int hours) {
    return '+$hours h';
  }

  @override
  String get kdsLinesPending => 'Details not received';

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
  String kdsTicket(String label) {
    return 'Ticket $label';
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
  String get kdsPairTitle => 'Pair this kitchen';

  @override
  String get kdsPairSubtitle =>
      'Pick the kiosk on the restaurant wifi, then approve on its screen.';

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
      'This kitchen will stop receiving orders from the current kiosk. You will have to pair it again.';

  @override
  String get kdsRepairCancel => 'Cancel';

  @override
  String get kdsRepairConfirm => 'Pair again';

  @override
  String kdsWithout(String ingredient) {
    return 'NO $ingredient';
  }

  @override
  String kdsGroupLabel(String group, String answer) {
    return '$group: $answer';
  }

  @override
  String get kdsGroupNone => 'NONE';

  @override
  String get kdsPairTap => 'Pair with one tap';

  @override
  String get kdsPairWaiting => 'Approve on the kiosk';

  @override
  String get kdsPairCompare =>
      'This number must match the one on the kiosk screen.';

  @override
  String get kdsPairOrCode => 'Or type the code shown on the kiosk';

  @override
  String get kdsPairErrorRefused => 'The kiosk refused this kitchen.';

  @override
  String get kdsDeleteTooltip => 'Delete ticket';

  @override
  String kdsDeleteTitle(String ticket) {
    return 'Delete ticket $ticket?';
  }

  @override
  String get kdsDeleteBody =>
      'The order will be cancelled. The customer has not paid.';

  @override
  String get kdsDeleteCancel => 'Keep';

  @override
  String get kdsDeleteConfirm => 'Delete';

  @override
  String get kdsViewPickerTitle => 'Which view for this tablet?';

  @override
  String get kdsViewKitchen => 'Kitchen';

  @override
  String get kdsViewKitchenHint => 'New → Preparing → Ready';

  @override
  String get kdsViewCashier => 'Cashier';

  @override
  String get kdsViewCashierHint => 'Kiosk tickets to collect';

  @override
  String get kdsSwitchView => 'Switch view';

  @override
  String get tvTitle => 'TIMMA dining-room screen';

  @override
  String get tvColumnPreparing => 'Preparing';

  @override
  String get tvColumnReady => 'Ready — please collect';

  @override
  String get tvEmptyReady => 'Your number will appear here';

  @override
  String get tvEmptyPreparing => 'No order in progress';

  @override
  String get tvOffline => 'Offline';

  @override
  String get tvSettingsTitle => 'Dining-room screen settings';

  @override
  String get tvSettingsOutput => 'Sound output (choose the TV)';

  @override
  String get tvSettingsVoice => 'Voice';

  @override
  String get tvSettingsTest => 'Test the voice';

  @override
  String get tvSettingsDefaultOutput => 'Windows default output';

  @override
  String get tvSettingsDefaultVoice => 'Default voice';

  @override
  String get tvSettingsNoFrenchVoice =>
      'No French voice installed — see the guide.';

  @override
  String get tvSettingsClose => 'Close';

  @override
  String get tvSettingsQuit => 'Quit the dining-room screen';

  @override
  String get tvSettingsHint => 'Press F2 to open the settings';

  @override
  String tvSayPreparing(String code) {
    return 'Order $code, being prepared.';
  }

  @override
  String tvSayReady(String code) {
    return 'Order $code is ready.';
  }

  @override
  String tvSayLine(int quantity, String name) {
    return '$quantity $name';
  }

  @override
  String tvSettingsTestPhrase(String code) {
    return 'Order $code is ready.';
  }
}
