import '../../domain/puntuacion/definicion_nivel.dart';
import '../../domain/puntuacion/resultado_puntaje.dart';
import '../../domain/puntuacion/estrategia_puntuacion.dart';

/// Selects the correct scoring strategy from [DefinicionNivel] data, computes the
/// raw score, and applies star thresholds (DM-F6).
///
/// Strategy selection is driven by [DefinicionNivel.esCronometrado] alone — never
/// by a subtype or a difficulty `if`. The use case is a pure function: identical
/// inputs always produce identical [ResultadoPuntaje]s, ensuring client–backend
/// agreement (AC5).
class CalcularPuntuacionUseCase {
  /// Creates the scoring use case. Stateless — no injected dependencies needed.
  const CalcularPuntuacionUseCase();

  /// Computes the [ResultadoPuntaje] for a completed level.
  ///
  /// [definicion] drives strategy selection and provides tuning data.
  /// [movimientos] is the total registered taps (valid + penalized).
  /// [segundosRestantes] is the remaining clock seconds (unused for untimed).
  ResultadoPuntaje calcular({
    required DefinicionNivel definicion,
    required int movimientos,
    required int segundosRestantes,
  }) {
    final EstrategiaPuntuacion estrategia = definicion.esCronometrado
        ? PuntuacionMixta(
            baseNivel: definicion.baseNivel,
            kmov: definicion.kmov,
            ktiempo: definicion.ktiempo,
          )
        : PuntuacionPorMovimientos(
            baseNivel: definicion.baseNivel,
            kmov: definicion.kmov,
          );

    final puntaje =
        estrategia.calcular(movimientos: movimientos, segundosRestantes: segundosRestantes);
    final estrellas = _calcularEstrellas(puntaje, definicion.umbralesEstrellas);

    return ResultadoPuntaje(puntaje: puntaje, estrellas: estrellas);
  }

  /// Walks the three ascending thresholds and returns the matching star count.
  ///
  /// A score at or above a threshold earns that star count. Below the first
  /// threshold is 0 stars. The thresholds are `[1-star, 2-star, 3-star]`.
  int _calcularEstrellas(int puntaje, List<int> umbrales) {
    for (var i = umbrales.length - 1; i >= 0; i--) {
      if (puntaje >= umbrales[i]) return i + 1;
    }
    return 0;
  }
}
