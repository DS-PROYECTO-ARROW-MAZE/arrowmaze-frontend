import 'package:arrowmaze/domain/puntuacion/puntuacion_por_movimientos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 06 — PuntuacionPorMovimientos (GoF Strategy): the untimed-level formula.
///
/// AC2: drops the time term; floor at 0 (large movimientos → 0, never negative).
void main() {
  test('should_drop_time_term_when_level_is_untimed', () {
    // Arrange — baseNivel=1000, Kmov=10 (no Ktiempo in untimed).
    const estrategia = PuntuacionPorMovimientos(
      baseNivel: 1000,
      kmov: 10,
    );

    // Act — 5 moves (secondsRestantes is irrelevant for untimed).
    final puntaje = estrategia.calcular(movimientos: 5, segundosRestantes: 0);

    // Assert — 1000 − 5·10 = 950 (time term dropped).
    expect(puntaje, 950);
  });

  test('should_floor_at_zero_when_movimientos_large', () {
    // Arrange — small base, realistic kmo.
    const estrategia = PuntuacionPorMovimientos(
      baseNivel: 100,
      kmov: 20,
    );

    // Act — 10 moves.
    final puntaje = estrategia.calcular(movimientos: 10, segundosRestantes: 0);

    // Assert — 100 − 10·20 = −100 → floored to 0.
    expect(puntaje, 0);
  });

  test('should_return_baseNivel_when_zero_movimientos', () {
    // Arrange
    const estrategia = PuntuacionPorMovimientos(
      baseNivel: 500,
      kmov: 10,
    );

    // Act
    final puntaje = estrategia.calcular(movimientos: 0, segundosRestantes: 0);

    // Assert — 500 − 0 = 500.
    expect(puntaje, 500);
  });
}
