import 'package:arrowmaze/domain/puntuacion/puntuacion_mixta.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 06 — PuntuacionMixta (GoF Strategy): the timed-level formula.
///
/// AC1: Puntaje == max(0, baseNivel − movimientos·Kmov + segundosRestantes·Ktiempo).
void main() {
  test('should_apply_full_formula_when_level_is_timed', () {
    // Arrange — baseNivel=1000, Kmov=10, Ktiempo=2.
    const estrategia = PuntuacionMixta(
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
    );

    // Act — 5 moves, 30 seconds remaining.
    final puntaje = estrategia.calcular(movimientos: 5, segundosRestantes: 30);

    // Assert — 1000 − 5·10 + 30·2 = 1000 − 50 + 60 = 1010.
    expect(puntaje, 1010);
  });

  test('should_floor_at_zero_when_formula_negative_on_timed_level', () {
    // Arrange — small base, large Kmov to drive the result below zero.
    const estrategia = PuntuacionMixta(
      baseNivel: 50,
      kmov: 20,
      ktiempo: 0,
    );

    // Act — 10 moves, 0 seconds left.
    final puntaje = estrategia.calcular(movimientos: 10, segundosRestantes: 0);

    // Assert — 50 − 10·20 = −150 → floored to 0.
    expect(puntaje, 0);
  });

  test('should_add_time_bonus_when_seconds_remaining_positive', () {
    // Arrange
    const estrategia = PuntuacionMixta(
      baseNivel: 500,
      kmov: 5,
      ktiempo: 3,
    );

    // Act — 0 moves, 60 seconds remaining.
    final puntaje = estrategia.calcular(movimientos: 0, segundosRestantes: 60);

    // Assert — 500 − 0 + 60·3 = 680.
    expect(puntaje, 680);
  });
}
