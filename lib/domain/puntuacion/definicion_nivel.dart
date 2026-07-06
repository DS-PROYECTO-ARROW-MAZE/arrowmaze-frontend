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
  static const _umbralCronometrado = 10;

  const DefinicionNivel({
    required this.id,
    this.numero = 0,
    required this.baseNivel,
    required this.kmov,
    required this.ktiempo,
    required this.umbralesEstrellas,
    Duration? limiteTiempo,
    this.esBonus = false,
  }) : _limiteTiempo = limiteTiempo;

  final int id;

  final int numero;

  final int baseNivel;

  final int kmov;

  final int ktiempo;

  final List<int> umbralesEstrellas;

  final Duration? _limiteTiempo;

  final bool esBonus;

  Duration? get limiteTiempo => esBonus ? null : _limiteTiempo;

  bool get esCronometrado => !esBonus && numero >= _umbralCronometrado && _limiteTiempo != null;
}
