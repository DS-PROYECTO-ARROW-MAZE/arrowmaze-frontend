import 'dart:math';

/// GoF **Strategy** — the scoring algorithm for a level (DM-F6).
///
/// Each concrete strategy implements one deterministic formula. The strategy is
/// selected from level data ([DefinicionNivel]) — never by subtyping on difficulty
/// or branching on an `if`. Adding a new formula is a new class that implements
/// this interface; callers never change (OCP).
///
/// There are exactly two concrete strategies:
/// - [PuntuacionMixta] for timed levels (moves + time terms)
/// - [PuntuacionPorMovimientos] for untimed levels (moves only)
///
/// `PuntuacionPorTiempo` must **not** exist (ticket 12 language guard).
abstract interface class EstrategiaPuntuacion {
  /// Computes the raw score for a play session.
  ///
  /// [movimientos] is the total taps registered as moves (valid + penalized).
  /// [segundosRestantes] is the remaining seconds on the clock (0 for untimed).
  int calcular({required int movimientos, required int segundosRestantes});
}

/// The **timed** scoring strategy: accounts for both moves and remaining time.
///
/// Formula: `Puntaje == max(0, baseNivel − movimientos·Kmov + segundosRestantes·Ktiempo)`
/// (AC1). The result is floored at zero so it can never be negative.
final class PuntuacionMixta implements EstrategiaPuntuacion {
  /// Creates a timed strategy with the given tuning data.
  const PuntuacionMixta({
    required this.baseNivel,
    required this.kmov,
    required this.ktiempo,
  });

  /// The level's base score (the "par" before deductions/bonuses).
  final int baseNivel;

  /// The weight penalising each registered move.
  final int kmov;

  /// The weight rewarding each second remaining on the clock.
  final int ktiempo;

  @override
  int calcular({required int movimientos, required int segundosRestantes}) {
    final raw = baseNivel - movimientos * kmov + segundosRestantes * ktiempo;
    return max(0, raw);
  }
}

/// The **untimed** scoring strategy: drops the time term entirely (AC2).
///
/// Formula: `Puntaje == max(0, baseNivel − movimientos·Kmov)`
/// The [ktiempo] exists on [DefinicionNivel] but is **ignored** here; the
/// strategy is chosen from level data, not by omitting the parameter.
final class PuntuacionPorMovimientos implements EstrategiaPuntuacion {
  /// Creates an untimed strategy with the given tuning data.
  const PuntuacionPorMovimientos({
    required this.baseNivel,
    required this.kmov,
  });

  /// The level's base score.
  final int baseNivel;

  /// The weight penalising each registered move.
  final int kmov;

  @override
  int calcular({required int movimientos, required int segundosRestantes}) {
    final raw = baseNivel - movimientos * kmov;
    return max(0, raw);
  }
}
