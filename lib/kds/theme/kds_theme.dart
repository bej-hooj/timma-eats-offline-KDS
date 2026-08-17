import 'package:flutter/material.dart';

import 'package:timma_kds/design/app_tokens.dart';
import 'kds_scale.dart';

/// The board's theme, in one place.
///
/// Extracted from `KdsApp` because the bootstrap screen runs *instead of* the
/// board — before any store or provider exists — and a tablet explaining why it
/// cannot open for service should still look like the product. Colours come
/// from `design/app_tokens.dart`, which is synced from `tokens.json`; no hex is
/// ever written here.
abstract final class KdsTheme {
  static ThemeData build() => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      error: AppColors.error,
      outline: AppColors.outline,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(KdsScale.minTarget),
        textStyle: const TextStyle(
          fontSize: KdsScale.bodySize,
          fontWeight: FontWeight.w700,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KdsScale.radius)),
        ),
      ),
    ),
  );
}
