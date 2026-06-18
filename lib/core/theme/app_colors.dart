import 'package:flutter/material.dart';

/// Color tokens for ArrowMaze — a *Dark Mode Neón Minimalista* palette.
///
/// This is the single source of truth for color in the app. Widgets should
/// never hard-code [Color] literals: they read either the Material
/// [ColorScheme] (assembled in `AppTheme`) or the game-specific tokens in
/// `GameTheme`, both of which are derived from the swatches defined here.
abstract final class AppColors {
  // --- Surfaces & text (chrome) ---------------------------------------------

  /// App-wide scaffold background (deepest layer).
  static const Color background = Color(0xFF1A1A24);

  /// Raised surfaces: cards, dialogs, text fields, the board frame.
  static const Color surface = Color(0xFF2A2A40);

  /// A slightly lighter surface for nested elevation (e.g. a cell over a board).
  static const Color surfaceVariant = Color(0xFF35354F);

  /// Primary text on dark surfaces.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary / muted text and hints.
  static const Color textSecondary = Color(0xFFA0A0B0);

  // --- Neon accents (palette) -----------------------------------------------

  /// Green neon — primary brand / success / valid-move signal.
  static const Color primaryNeon = Color(0xFF4ADE80);

  /// Cyan neon — secondary accent / default arrow tint / focus.
  static const Color accentNeon = Color(0xFF38BDF8);

  /// Bright yellow — collectibles, stars, warnings.
  static const Color warningNeon = Color(0xFFFDE047);

  /// Soft red — errors and the invalid-move signal.
  static const Color errorNeon = Color(0xFFF87171);

  /// Purple neon — tertiary accent (special arrows, highlights).
  static const Color purpleNeon = Color(0xFFC084FC);
}
