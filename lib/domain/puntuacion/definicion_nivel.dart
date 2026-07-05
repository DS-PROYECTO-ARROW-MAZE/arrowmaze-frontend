import 'dart:math';

/// Holds the tuning **data** for a level's scoring algorithm (DM-F6).
///
/// This is a pure data entity — it carries no behaviour. The
/// [CalcularPuntuacionUseCase] reads it to select the correct strategy
/// ([PuntuacionMixta] or [PuntuacionPorMovimientos]) and to pass tuning
/// constants. All tuning lives here so the algorithm swaps without touching
/// callers (OCP).
///
/// [referencia] is the maximum achievable score for this level, derived from
/// the strategy's ideal inputs (0 moves, full time). Stars are assigned via
/// proportional bands against this reference (Ticket 19).
class DefinicionNivel {
  static const _umbralCronometrado = 10;

  const DefinicionNivel({
    required this.id,
    this.numero = 0,
    required this.baseNivel,
    required this.kmov,
    required this.ktiempo,
    Duration? limiteTiempo,
    this.esBonus = false,
  }) : _limiteTiempo = limiteTiempo;

  final int id;

  final int numero;

  final int baseNivel;

  final int kmov;

  final int ktiempo;

  final Duration? _limiteTiempo;

  final bool esBonus;

  Duration? get limiteTiempo => esBonus ? null : _limiteTiempo;

  bool get esCronometrado => !esBonus && numero >= _umbralCronometrado && _limiteTiempo != null;

  /// The maximum achievable score for this level.
  ///
  /// For timed levels: `baseNivel + limiteTiempo * ktiempo` (0 moves, full time).
  /// For untimed levels: just `baseNivel` (0 moves).
  int get referencia {
    if (esCronometrado) {
      return max(0, baseNivel + _limiteTiempo!.inSeconds * ktiempo);
    }
    return baseNivel;
  }
}
