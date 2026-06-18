import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';
import 'game_theme.dart';

/// Assembles ArrowMaze's global [ThemeData] from the design tokens
/// (`AppColors`, `AppSpacing`/`AppRadii`/`AppDurations`, `AppTypography`) and
/// registers the game-specific [GameTheme] extension.
///
/// Views consume this through `MaterialApp(theme: AppTheme.darkTheme)` and read
/// game tokens via `Theme.of(context).extension<GameTheme>()!`. No widget
/// should declare raw colors, sizes, or durations of its own.
abstract final class AppTheme {
  /// The single dark theme for the app (Dark Mode Neón Minimalista).
  static ThemeData get darkTheme {
    final ColorScheme scheme = const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.primaryNeon,
      secondary: AppColors.accentNeon,
      error: AppColors.errorNeon,
      onPrimary: AppColors.background,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryNeon,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme,

      // Game tokens, reachable via Theme.of(context).extension<GameTheme>().
      extensions: const <ThemeExtension<dynamic>>[GameTheme.dark],

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.titleLarge,
      ),

      // Primary "pill" actions: bright fill, dark label for max contrast.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNeon,
          foregroundColor: AppColors.background,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),

      // Secondary / low-emphasis actions.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentNeon,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Cards: level tiles, leaderboard rows, victory/defeat panels.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: const EdgeInsets.all(AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),

      // Dialogs (pause overlay, confirmations).
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        titleTextStyle: AppTypography.titleLarge,
        contentTextStyle: AppTypography.bodyLarge,
      ),

      // Login / register input fields.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.accentNeon, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.errorNeon, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.errorNeon, width: 2),
        ),
      ),
    );
  }
}
