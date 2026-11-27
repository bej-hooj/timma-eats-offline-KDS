import 'package:pos_core/pos_core.dart';

/// Every rule the dining-room TV follows, in one place (S6, plan §3).
///
/// Owner decisions 2026-11-25 (Session 3) and 2026-11-27. No widget, timer or
/// sentence elsewhere may carry one of these numbers as a literal.
abstract final class TvRules {
  /// Only borne orders: app and web customers follow theirs in the app.
  static const String source = PosOrderSource.kiosk;

  /// « En préparation ». `placed` is included (2026-11-27) so a customer who
  /// has just paid sees their number at once, before a cook taps it.
  static const Set<String> preparingStatuses = <String>{
    PosOrderStatus.placed,
    PosOrderStatus.accepted,
    PosOrderStatus.preparing,
  };

  /// « Prêt — à récupérer ».
  static const String readyStatus = PosOrderStatus.ready;

  /// How long a ready number stays on screen (owner: three minutes).
  static const Duration readyVisibleFor = Duration(minutes: 3);

  /// A number that became ready this recently is drawn highlighted.
  static const Duration highlightFor = Duration(seconds: 10);

  /// While numbers are ready, one of them is re-announced this often, in turn.
  static const Duration rotationEvery = Duration(seconds: 30);

  /// The TV re-reads its local store this often — a SQLite read, not network.
  static const Duration refreshEvery = Duration(seconds: 2);

  /// Tiles per column. A TV that scrolls is a TV nobody can read.
  static const int maxPerColumn = 12;

  /// Utterances waiting to be spoken; beyond this, preparation ones drop.
  static const int maxQueue = 10;

  /// Longest text the native speech channel accepts (it enforces it too).
  static const int maxSpeechChars = 500;

  /// Speaking speed, 1.0 = the voice's normal pace. Slower so a ticket code
  /// is understood across a noisy dining room (owner, 2026-11-27: « pas
  /// clair »). The native channel accepts 0.5–1.5.
  static const double speakingRate = 0.85;

  /// The mouse cursor hides after this long without movement.
  static const Duration cursorHideAfter = Duration(seconds: 3);
}
