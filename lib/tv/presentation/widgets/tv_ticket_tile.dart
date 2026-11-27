import 'package:flutter/material.dart';

import '../tv_palette.dart';

/// One number on the TV. Only the code — never dishes, prices or names.
///
/// The single animation of this view: a freshly ready number is drawn larger
/// for [TvRules.highlightFor] and settles back.
class TvTicketTile extends StatelessWidget {
  const TvTicketTile({
    required this.label,
    required this.ready,
    required this.highlighted,
    required this.size,
    super.key,
  });

  final String label;
  final bool ready;
  final bool highlighted;
  final Size size;

  static const Duration _settle = Duration(milliseconds: 600);
  static const double _highlightScale = 1.12;

  @override
  Widget build(BuildContext context) {
    final Color background = ready ? TvPalette.readyTile : TvPalette.preparingTile;
    final Color foreground = ready ? TvPalette.onReadyTile : TvPalette.onPreparing;
    return AnimatedScale(
      scale: highlighted ? _highlightScale : 1,
      duration: _settle,
      curve: Curves.easeOutBack,
      child: Container(
        width: size.width,
        height: size.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size.height * 0.16),
        ),
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: foreground,
              fontSize: size.height * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: size.height * 0.03,
            ),
          ),
        ),
      ),
    );
  }
}
