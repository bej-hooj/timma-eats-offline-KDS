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

  /// For small square things inside a card — a dish thumbnail. The card's own
  /// 16 looks like a bubble at 56 dp; half of it reads as the same family.
  static const double radiusSmall = 8;

  /// A dish thumbnail on a ticket line.
  ///
  /// 52, not 72: this is a RECOGNITION aid for a cook who is already holding
  /// the card's name in view, not the kiosk's shopping picture. It also has to
  /// coexist with up to five option lines per dish on a card that already
  /// scrolls, and every dp here comes off the text a cook actually reads.
  static const double thumbSide = 52;

  /// The widest a lane column should ever be, on a big kitchen tablet.
  static const double laneWidthMax = 320;

  /// The narrowest a lane may be squeezed to before scrolling is the better
  /// answer. Below this a ticket's dish names start wrapping to three lines and
  /// the card stops being readable across a kitchen.
  static const double laneWidthMin = 200;

  /// How wide each column should be so [count] lanes fill [available].
  ///
  /// ⚠ **A fixed 320 fitted 2.6 lanes on the board this ships on.** The cuisine
  /// is 844 dp wide in landscape, so a cook had to scroll horizontally to see
  /// *Prêtes* — the lane that says an order is ready to hand over. A board you
  /// scroll to read is a board that gets read late. The columns now divide the
  /// width they are given, down to [laneWidthMin]; past that scrolling returns,
  /// which is the right answer for a genuinely crowded board.
  static double laneWidthFor({required double available, required int count}) {
    if (count <= 0) {
      return laneWidthMax;
    }
    final double share = (available - gapMd * (count - 1)) / count;
    // ⚠ **The floor must not apply to the spine.** With a 200 dp minimum, four
    // lanes needed 848 dp and the board has 796 — so the width silently
    // clamped back up, the row overflowed, and *Prêtes* sat off the right edge
    // behind a scroll again. The four spine lanes are the whole job of this
    // screen: they fit whatever they are given. A floor only makes sense once
    // *Programmées* or *En livraison* has joined them, where scrolling a
    // genuinely crowded board is the honest answer.
    if (count <= spineLaneCount) {
      return share.clamp(0, laneWidthMax);
    }
    return share.clamp(laneWidthMin, laneWidthMax);
  }

  /// Kept here rather than imported from `KdsLane` so this file stays free of
  /// domain imports; asserted equal to `KdsLane.spine.length` in the tests.
  static const int spineLaneCount = 4;
}
