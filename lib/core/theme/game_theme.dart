import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Game-specific design tokens, exposed as a Material [ThemeExtension].
///
/// These map the neon palette onto ArrowMaze's *UI* vocabulary — the four
/// `Celda` kinds (`Flecha`, `CeldaPared`, `CeldaVacia`, `Coleccionable`), the
/// valid/invalid move feedback, and the 1–3 star rating. The board renderer
/// (`TableroUI`/`CeldaUI`, DM-F8) reads these via
/// `Theme.of(context).extension<GameTheme>()!` so visual tuning never leaks
/// into widgets — and never anywhere near the domain.
///
/// Note: there is deliberately **no** exit/target cell token — ArrowMaze has no
/// `CeldaSalida` (PRD §4 avoid-list).
@immutable
class GameTheme extends ThemeExtension<GameTheme> {
  /// Creates a game theme with every token specified.
  const GameTheme({
    required this.boardBackground,
    required this.boardGridLine,
    required this.emptyDot,
    required this.arrowPalette,
    required this.cellArrow,
    required this.cellArrowGlow,
    required this.cellWall,
    required this.cellEmpty,
    required this.cellCollectible,
    required this.collectibleGlow,
    required this.validMoveFlash,
    required this.invalidMoveFlash,
    required this.starActive,
    required this.starInactive,
  });

  /// Backdrop behind the grid.
  final Color boardBackground;

  /// Thin lines separating cells.
  final Color boardGridLine;

  /// The subtle dot marking an empty grid space (no background tile).
  final Color emptyDot;

  /// The cycle of neon colours assigned to distinct arrow paths, so adjacent
  /// continuous paths read as separate arrows. Indexed by `idFlecha % length`.
  final List<Color> arrowPalette;

  /// Fill/tint of an interactive `Flecha` cell.
  final Color cellArrow;

  /// Glow cast by an arrow (use as a shadow/blur color).
  final Color cellArrowGlow;

  /// Fill of a blocking `CeldaPared`.
  final Color cellWall;

  /// Fill of a passable `CeldaVacia` (the ray flies over it).
  final Color cellEmpty;

  /// Fill/tint of a `Coleccionable` (bonus time, transparent to rays).
  final Color cellCollectible;

  /// Glow around a collectible.
  final Color collectibleGlow;

  /// Flash shown when a tap is a **valid** move (arrow exits).
  final Color validMoveFlash;

  /// Flash/shake tint shown when a tap is an **invalid** move (penalized).
  final Color invalidMoveFlash;

  /// A filled star in the 1–3 rating.
  final Color starActive;

  /// An unfilled star slot.
  final Color starInactive;

  /// A colour for the path with [idFlecha], cycling through [arrowPalette].
  Color colorFlecha(int idFlecha) =>
      arrowPalette[idFlecha % arrowPalette.length];

  /// The default game palette for the dark theme.
  static const GameTheme dark = GameTheme(
    boardBackground: AppColors.background,
    boardGridLine: AppColors.surfaceVariant,
    emptyDot: AppColors.surfaceVariant,
    arrowPalette: <Color>[
      AppColors.accentNeon,
      AppColors.primaryNeon,
      AppColors.purpleNeon,
      AppColors.warningNeon,
      AppColors.errorNeon,
    ],
    cellArrow: AppColors.accentNeon,
    cellArrowGlow: AppColors.accentNeon,
    cellWall: AppColors.surfaceVariant,
    cellEmpty: AppColors.surface,
    cellCollectible: AppColors.warningNeon,
    collectibleGlow: AppColors.warningNeon,
    validMoveFlash: AppColors.primaryNeon,
    invalidMoveFlash: AppColors.errorNeon,
    starActive: AppColors.warningNeon,
    starInactive: AppColors.surfaceVariant,
  );

  @override
  GameTheme copyWith({
    Color? boardBackground,
    Color? boardGridLine,
    Color? emptyDot,
    List<Color>? arrowPalette,
    Color? cellArrow,
    Color? cellArrowGlow,
    Color? cellWall,
    Color? cellEmpty,
    Color? cellCollectible,
    Color? collectibleGlow,
    Color? validMoveFlash,
    Color? invalidMoveFlash,
    Color? starActive,
    Color? starInactive,
  }) {
    return GameTheme(
      boardBackground: boardBackground ?? this.boardBackground,
      boardGridLine: boardGridLine ?? this.boardGridLine,
      emptyDot: emptyDot ?? this.emptyDot,
      arrowPalette: arrowPalette ?? this.arrowPalette,
      cellArrow: cellArrow ?? this.cellArrow,
      cellArrowGlow: cellArrowGlow ?? this.cellArrowGlow,
      cellWall: cellWall ?? this.cellWall,
      cellEmpty: cellEmpty ?? this.cellEmpty,
      cellCollectible: cellCollectible ?? this.cellCollectible,
      collectibleGlow: collectibleGlow ?? this.collectibleGlow,
      validMoveFlash: validMoveFlash ?? this.validMoveFlash,
      invalidMoveFlash: invalidMoveFlash ?? this.invalidMoveFlash,
      starActive: starActive ?? this.starActive,
      starInactive: starInactive ?? this.starInactive,
    );
  }

  @override
  GameTheme lerp(covariant ThemeExtension<GameTheme>? other, double t) {
    if (other is! GameTheme) return this;
    return GameTheme(
      boardBackground: Color.lerp(boardBackground, other.boardBackground, t)!,
      boardGridLine: Color.lerp(boardGridLine, other.boardGridLine, t)!,
      emptyDot: Color.lerp(emptyDot, other.emptyDot, t)!,
      arrowPalette: t < 0.5 ? arrowPalette : other.arrowPalette,
      cellArrow: Color.lerp(cellArrow, other.cellArrow, t)!,
      cellArrowGlow: Color.lerp(cellArrowGlow, other.cellArrowGlow, t)!,
      cellWall: Color.lerp(cellWall, other.cellWall, t)!,
      cellEmpty: Color.lerp(cellEmpty, other.cellEmpty, t)!,
      cellCollectible: Color.lerp(cellCollectible, other.cellCollectible, t)!,
      collectibleGlow: Color.lerp(collectibleGlow, other.collectibleGlow, t)!,
      validMoveFlash: Color.lerp(validMoveFlash, other.validMoveFlash, t)!,
      invalidMoveFlash: Color.lerp(invalidMoveFlash, other.invalidMoveFlash, t)!,
      starActive: Color.lerp(starActive, other.starActive, t)!,
      starInactive: Color.lerp(starInactive, other.starInactive, t)!,
    );
  }
}
