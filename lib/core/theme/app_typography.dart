import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography tokens for ArrowMaze.
///
/// The design calls for the *Nunito* family (rounded, friendly, casual-puzzle
/// feel). Set [fontFamily] to `'Nunito'` once the font is bundled in
/// `pubspec.yaml`; until then it falls back to the platform default while
/// keeping every size/weight decision in one place.
abstract final class AppTypography {
  /// The intended family. `null` uses the system fallback.
  static const String? fontFamily = null; // -> 'Nunito' when bundled.

  /// Large display text (splash / big titles, e.g. "ArrowMaze").
  static const TextStyle displayLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  /// Screen titles ("Select Level", "Victory").
  static const TextStyle titleLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  /// Section headings / card titles.
  static const TextStyle titleMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  /// Primary body text.
  static const TextStyle bodyLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
  );

  /// Secondary / supporting body text.
  static const TextStyle bodyMedium = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
  );

  /// HUD numerics (moves, timer, score) — tabular, prominent.
  static const TextStyle hudNumber = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Assembles the Material [TextTheme] consumed by `AppTheme`.
  static TextTheme get textTheme => const TextTheme(
        displayLarge: displayLarge,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
      ).apply(fontFamily: fontFamily);
}
