/// Holds the tuning **data** for a level's scoring algorithm (DM-F6).
///
/// This is a pure data entity — it carries no behaviour. The
/// [CalcularPuntuacionUseCase] reads it to select the correct strategy
/// ([PuntuacionMixta] or [PuntuacionPorMovimientos]) and to pass tuning
/// constants. All tuning lives here so the algorithm swaps without touching
/// callers (OCP).
///
/// [umbralesEstrellas] contains exactly three thresholds in ascending order:
/// `[1-star, 2-star, 3-star]`. A score at or above a threshold earns that star
/// count.
class DefinicionNivel {
  /// Creates a level scoring definition.
  const DefinicionNivel({
    required this.id,
    required this.baseNivel,
    required this.kmov,
    required this.ktiempo,
    required this.umbralesEstrellas,
    this.limiteTiempo,
  });

  /// The level's unique identifier.
  final int id;

  /// The level's base score (the "par" before deductions/bonuses).
  final int baseNivel;

  /// The weight penalising each registered move.
  final int kmov;

  /// The weight rewarding each remaining second (zeroed by
  /// [PuntuacionPorMovimientos] on untimed levels).
  final int ktiempo;

  /// Three ascending thresholds: `[1-star, 2-star, 3-star]`.
  final List<int> umbralesEstrellas;

  /// The level's time limit, or `null` for an untimed level.
  ///
  /// This is the single datum that drives strategy selection — never a subtype
  /// or `if` on difficulty.
  final Duration? limiteTiempo;

  /// Whether the level is timed (strategy-selection flag).
  bool get esCronometrado => limiteTiempo != null;
}
