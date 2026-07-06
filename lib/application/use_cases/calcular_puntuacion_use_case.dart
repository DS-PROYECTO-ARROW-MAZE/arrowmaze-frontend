import '../../domain/puntuacion/definicion_nivel.dart';
import '../../domain/puntuacion/resultado_puntaje.dart';
import '../../domain/puntuacion/estrategia_puntuacion.dart';

/// Selects the correct scoring strategy from [DefinicionNivel] data, computes the
/// raw score, and assigns star rating via proportional bands (Ticket 19).
///
/// Strategy selection is driven by [DefinicionNivel.esCronometrado] alone — never
/// by a subtype or a difficulty `if`. The use case is a pure function: identical
/// inputs always produce identical [ResultadoPuntaje]s, ensuring client–backend
/// agreement.
///
/// Stars are proportional to [`puntaje` / `referencia`]:
///   3★:  `puntaje * 10 >= referencia * 9`  (≥ 9/10 of max)
///   2★:  `puntaje * 3 >= referencia * 3` ... actually
///   2★:  `puntaje * 3 >= referencia * 2`  (≥ 2/3 of max)
///   1★:  anything below 2/3
///
/// Integer cross-multiplication avoids float drift. Bonus levels short-circuit
/// to zero score and zero stars.
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
    if (definicion.esBonus) {
      return const ResultadoPuntaje(puntaje: 0, estrellas: 0);
    }

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
    final estrellas = _calcularEstrellas(puntaje, definicion.referencia);

    return ResultadoPuntaje(puntaje: puntaje, estrellas: estrellas);
  }

  /// Assigns star rating via proportional bands against [referencia].
  ///
  /// Integer cross-multiplication guarantees no float drift:
  ///   3★: `puntaje * 10 >= referencia * 9`
  ///   2★: `puntaje * 3 >= referencia * 2`
  ///   1★: fallthrough (anything below 2/3)
  int _calcularEstrellas(int puntaje, int referencia) {
    if (puntaje * 10 >= referencia * 9) return 3;
    if (puntaje * 3 >= referencia * 2) return 2;
    return 1;
  }
}
