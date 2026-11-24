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

  /// The least height a ticket card may be given, whatever the lane's own
  /// height is.
  ///
  /// ⚠⚠ **Measured on the kitchen Samsung, 2026-11-24, with a live order:
  /// the card was capped at 153 dp.** The cap was the lane's VISIBLE height —
  /// "no card taller than the space a cook can see" — and in landscape that
  /// phone is 411 dp tall, so after the board header and the lane header there
  /// were 153 left. The chips and the 72 dp action button fill that on their
  /// own, so the card rendered them and silently dropped the ticket code, the
  /// dishes and the total. The data was all there: `lines=1`, `total=5100`,
  /// `label=01`.
  ///
  /// A card that does not fit must be SCROLLED TO, not emptied. The lane is a
  /// list and already scrolls; a half-visible card a cook can pull up beats a
  /// whole one that says nothing.
  static const double cardMinHeight = 280;

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
      // ⚠ **A floor even for the spine, just a much lower one.**
      //
      // The floor WAS removed here, and for a good reason: at 200 dp the four
      // spine lanes needed 848 dp, the board had 796, the width clamped back
      // up and *Prêtes* sat off the right edge behind a scroll.
      //
      // But "they fit whatever they are given" has no bottom, and a 640 dp
      // screen gives each lane 136 dp — narrower than a ticket card can draw
      // itself, which showed up as a RenderFlex overflow on the card's own
      // header. Below [laneWidthFloor] the honest answer is the horizontal
      // scroll the lane list already has: a cook can reach a lane that is off
      // the edge, and cannot read one that is painted over.
      //
      // 160 is under the 187 dp the 796 dp board gives, so it never binds on
      // any real board — only on screens too small to hold the spine at all.
      return share.clamp(laneWidthFloor, laneWidthMax);
    }
    return share.clamp(laneWidthMin, laneWidthMax);
  }

  /// The narrowest a lane may be drawn before the board scrolls instead.
  ///
  /// ⚠⚠ **Measured on the real pair, 2026-11-24, with a live order.** At 160
  /// the Samsung's four lanes are 183 dp and the card inside is 148 — and at
  /// 148 the card is not merely tight, it is UNREADABLE: the *Borne* chip
  /// wrapped to "Born/e", *Encaisser en espèce* wrapped to three lines and was
  /// clipped, the paid chip never appeared, and the ticket code, the dishes
  /// and the total were pushed out of the card's scroll area entirely. A
  /// kitchen board that shows a cook neither what to cook nor which ticket it
  /// is has failed at its only job.
  ///
  /// ⚠ 240, not 280, and the number comes from a real screen: the GM92 the
  /// restaurant mounts is **1097 dp** wide in landscape, which leaves 1 049
  /// for the lanes. Four 280 dp lanes want 1 192 and would have made that
  /// board scroll; at 240 they want 1 008 and all four are on screen at once.
  ///
  /// 240 still leaves the card 208 dp — comfortably past the 148 that made it
  /// unreadable — and the Windows PC and any television have room to spare.
  static const double laneWidthFloor = 240;

  /// Kept here rather than imported from `KdsLane` so this file stays free of
  /// domain imports; asserted equal to `KdsLane.spine.length` in the tests.
  static const int spineLaneCount = 4;

  /// A lane heading never shrinks below this. Under it the board is being
  /// asked to do something it cannot do well, and an ellipsis is the honest
  /// answer rather than type nobody can read from two metres.
  static const double laneTitleMinSize = 16;

  /// The ONE size every lane heading uses, chosen so the longest of [titles]
  /// fits the room a lane actually has — **over two lines**.
  ///
  /// ⚠ **Shared, not per lane.** Letting each heading shrink on its own —
  /// which is what a `FittedBox` per lane does — gives four different type
  /// sizes across four adjacent columns, and the board reads as if the
  /// headings were ranked. Measured on the Samsung 2026-11-23: *En
  /// préparation* came out visibly smaller than *Prêtes* beside it.
  ///
  /// ⚠ **Two lines, and the constraint is the longest WORD.** On the Samsung
  /// a lane is 183 dp wide: *En préparation* on ONE line needs about 13 dp of
  /// type, which is not a heading on a board read from two metres. Across two
  /// lines the binding constraint becomes *préparation* on its own, and the
  /// same lane carries it at about 22 dp. A board on a television has lanes
  /// four times as wide and every title stays at [titleSize] — this only ever
  /// shrinks.
  ///
  /// [measure] returns the width of a string at [titleSize]; the caller
  /// supplies it so this stays a pure function of numbers and can be checked
  /// without a widget tree. It must measure at the viewer's own text scale —
  /// see `_measure` in `board_screen.dart` for what ignoring that cost.
  static double laneTitleSize({
    required Iterable<String> titles,
    required double laneWidth,
    required double countChipWidth,
    required double Function(String) measure,
  }) {
    // The lane's own padding, the gap before the count, and the count chip.
    //
    // ⚠ And a cushion, measured rather than guessed: probed on the Samsung,
    // the computation returned a size whose laid-out line was within a
    // fraction of a dp of its box, and text layout rounds the wrong way at
    // that margin. A heading that fits EXACTLY is a heading that ellipsizes.
    final double room = laneWidth - gapMd * 2 - gap - countChipWidth - _cushion;
    if (room <= 0) {
      return laneTitleMinSize;
    }
    double scale = 1;
    void limit(double value) {
      if (value > 0 && value < scale) {
        scale = value;
      }
    }

    for (final String title in titles) {
      // No word may be cut, whatever wrapping does.
      for (final String word in title.split(' ')) {
        limit(room / measure(word));
      }
      // And the whole title has to land inside two of those lines. The 0.95
      // is for the wrap itself: two lines of a two-word title are never two
      // perfectly full lines.
      limit(room * 2 * 0.95 / measure(title));
    }
    final double size = titleSize * scale;
    return size.clamp(laneTitleMinSize, titleSize);
  }

  /// A lane heading is drawn on at most this many lines.
  static const int laneTitleMaxLines = 2;

  /// Slack between the longest heading and its box. See [laneTitleSize].
  static const double _cushion = 6;

  /// The horizontal padding inside the count chip, both sides together. The
  /// caller adds it to the measured digits.
  static const double laneCountChipPadding = gap * 2;

  /// A lane heading never goes under this once the chip is measured
  /// accurately; below it the type is too small for a board read at two
  /// metres, and the honest answer is a shorter lane name, not smaller type.
  ///
  /// Kept well under [titleSize] so French — the longer language, and the one
  /// the board runs in — never reaches it on the four spine lanes.
}
