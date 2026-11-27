import 'package:pos_core/pos_core.dart';

/// Every rule the dining-room TV follows, in one place (S6, plan §3).
///
/// Owner decisions 2026-11-25 (Session 3) and 2026-11-27. No widget, timer or
/// sentence elsewhere may carry one of these numbers as a literal.
abstract final class TvRules {
  /// Only borne orders: app and web customers follow theirs in the app.
  static const String source = PosOrderSource.kiosk;

  // Which column a ticket sits in is NOT decided here: the TV reuses the
  // kitchen board's own rule, `KdsLane.laneFor` (owner, 2026-11-27: the TV
  // must show exactly what the KDS marks « En préparation » and « Prêtes »).

  /// How long a ready number stays on screen (owner: three minutes).
  static const Duration readyVisibleFor = Duration(minutes: 3);

  /// A number that became ready this recently is drawn highlighted.
  static const Duration highlightFor = Duration(seconds: 10);

  /// Once every new move has been said and the voice has been silent this
  /// long, the TV re-reads the whole board — « Prêt » first, then « En
  /// préparation » — and starts again (owner, 2026-11-27).
  static const Duration cyclePause = Duration(seconds: 20);

  /// The TV re-reads its local store this often — a SQLite read, not network.
  static const Duration refreshEvery = Duration(seconds: 2);

  /// Tiles per column. A TV that scrolls is a TV nobody can read.
  static const int maxPerColumn = 12;

  /// Utterances waiting to be spoken — room for a full re-read of both
  /// columns plus fresh announcements. Beyond it, re-reads drop first.
  static const int maxQueue = maxPerColumn * 2 + 6;

  /// Longest text the native speech channel accepts (it enforces it too).
  static const int maxSpeechChars = 500;

  /// Speaking speed, 1.0 = the voice's normal pace. Slower so a ticket code
  /// is understood across a noisy dining room (owner, 2026-11-27: « pas
  /// clair »). The native channel accepts 0.5–1.5.
  static const double speakingRate = 0.85;

  /// The mouse cursor hides after this long without movement.
  static const Duration cursorHideAfter = Duration(seconds: 3);
}
