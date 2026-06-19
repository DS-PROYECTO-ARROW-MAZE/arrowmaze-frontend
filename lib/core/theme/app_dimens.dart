import 'package:flutter/widgets.dart';

/// Spacing scale (4-point grid). Use these instead of magic numbers for
/// padding, gaps, and margins so layouts stay consistent across screens.
abstract final class AppSpacing {
  /// 4 — hairline gaps.
  static const double xs = 4;

  /// 8 — tight padding between related elements.
  static const double sm = 8;

  /// 16 — default content padding.
  static const double md = 16;

  /// 24 — section spacing / screen gutters.
  static const double lg = 24;

  /// 32 — large separation between blocks.
  static const double xl = 32;

  /// 48 — hero spacing (top of menus, around the board).
  static const double xxl = 48;
}

/// Corner radii. The pill shape is the brand affordance for primary actions.
abstract final class AppRadii {
  /// 8 — board cells.
  static const double cell = 8;

  /// 16 — text fields and small chips.
  static const double field = 16;

  /// 20 — cards (level tiles, leaderboard rows, victory/defeat panels).
  static const double card = 20;

  /// 24 — primary "pill" buttons.
  static const double pill = 24;

  /// As a ready-to-use [BorderRadius] for cards.
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
}

/// Animation durations.
///
/// Gameplay logic must resolve and render within a single frame (≤ 16 ms,
/// PRD §1.5); these tokens are for *presentation* transitions only — the
/// arrow-exit flourish, screen changes, and feedback flashes.
abstract final class AppDurations {
  /// 120 ms — tap feedback, button press, invalid-move shake.
  static const Duration fast = Duration(milliseconds: 120);

  /// 240 ms — arrow-exit animation, cell state changes.
  static const Duration normal = Duration(milliseconds: 240);

  /// 400 ms — screen transitions, victory/defeat reveal.
  static const Duration slow = Duration(milliseconds: 400);
}
