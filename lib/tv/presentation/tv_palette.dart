import 'package:flutter/painting.dart';

import 'package:timma_kds/design/app_tokens.dart';

/// The TV's colours — brand tokens only, no hex here.
abstract final class TvPalette {
  static const Color header = AppColors.brandGreen;
  static const Color onHeader = AppColors.brandGold;

  /// « En préparation »: calm cream.
  static const Color preparing = AppColors.brandCream;
  static const Color onPreparing = AppColors.brandCharcoal;
  static const Color preparingTile = AppColors.surface;

  /// « Prêt »: the brand green the customer is waiting for.
  static const Color ready = AppColors.brandGreen;
  static const Color onReady = AppColors.brandGold;
  static const Color readyTile = AppColors.brandGold;
  static const Color onReadyTile = AppColors.brandGreen;

  static const Color offline = AppColors.error;
  static const Color onOffline = AppColors.onError;
}
