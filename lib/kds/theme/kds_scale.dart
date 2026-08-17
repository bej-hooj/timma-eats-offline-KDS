/// The kitchen board's metrics.
///
/// A cook stands at the same distance as a kiosk customer, so type stays large
/// — but the two surfaces want opposite densities and that is why this is not
/// `KioskScale` under another name. A customer reads **one** dish at a time and
/// the photography carries the screen; a cook has to see the **whole queue** at
/// once, because a ticket you have to scroll to find is a ticket that ages
/// unseen. Cards are therefore compact where the kiosk's are generous.
///
/// Touch targets do **not** shrink with the cards. Kitchen hands are wet,
/// gloved, or holding a plate, and the one-tap advance is the control the whole
/// board exists around.
abstract final class KdsScale {
  /// Same floor as the kiosk. A missed tap here re-fires a transition or, worse,
  /// hits the neighbouring ticket.
  static const double minTarget = 72;

  static const double gap = 8;
  static const double gapMd = 16;
  static const double gapLg = 24;
  static const double gapXl = 32;

  static const double labelSize = 16;
  static const double bodySize = 20;
  static const double titleSize = 26;
  static const double headlineSize = 34;

  /// The ticket total, sized so staff can count change against it across a
  /// counter without leaning in (plan §K5).
  static const double totalSize = 40;

  static const double radius = 16;

  /// One lane column. Six lanes on a 1200-logical tablet means horizontal
  /// scrolling is expected and fine — a cook swipes to the lane they work.
  static const double laneWidth = 320;
}
