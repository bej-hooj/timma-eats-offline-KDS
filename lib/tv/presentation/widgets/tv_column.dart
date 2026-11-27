import 'package:flutter/material.dart';

import '../../domain/tv_board.dart';
import '../../domain/tv_rules.dart';
import '../../domain/tv_ticket.dart';
import '../tv_palette.dart';
import 'tv_ticket_tile.dart';

/// One column of the TV: a title and a grid of numbers sized from the space it
/// has — never fixed pixels, so it reads the same on a 32" and a 55" screen.
class TvColumnView extends StatelessWidget {
  const TvColumnView({
    required this.title,
    required this.emptyText,
    required this.tickets,
    required this.ready,
    required this.now,
    super.key,
  });

  final String title;
  final String emptyText;
  final List<TvTicket> tickets;
  final bool ready;
  final DateTime now;

  /// 3 × 4 = [TvRules.maxPerColumn] tiles.
  static const int _perRow = 3;
  static const int _rows = TvRules.maxPerColumn ~/ _perRow;

  @override
  Widget build(BuildContext context) {
    final Color background = ready ? TvPalette.ready : TvPalette.preparing;
    final Color foreground = ready ? TvPalette.onReady : TvPalette.onPreparing;
    return ColoredBox(
      color: background,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double gap = box.maxWidth * 0.025;
          final double titleSize = box.maxHeight * 0.075;
          final double gridHeight = box.maxHeight - titleSize * 2.2 - gap * 2;
          final double tileW = (box.maxWidth - gap * (_perRow + 1)) / _perRow;
          final double tileH = ((gridHeight - gap * (_rows - 1)) / _rows).clamp(0, tileW * 0.62);
          return Padding(
            padding: EdgeInsets.all(gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: titleSize * 1.8,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: TextStyle(color: foreground, fontSize: titleSize, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SizedBox(height: gap),
                Expanded(
                  child: tickets.isEmpty
                      ? Center(
                          child: Text(
                            emptyText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: foreground.withValues(alpha: 0.7),
                              fontSize: titleSize * 0.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: <Widget>[
                            for (final TvTicket t in tickets)
                              TvTicketTile(
                                key: ValueKey<String>(t.clientId),
                                label: t.label,
                                ready: ready,
                                highlighted: TvBoard.isHighlighted(t, now),
                                size: Size(tileW, tileH),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
