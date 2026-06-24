import 'package:arrowmaze/application/use_cases/calcular_puntuacion_use_case.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 06 — CalcularPuntuacionUseCase: strategy selection + star thresholds
/// + golden fixture parity (AC3, AC4, AC5).
void main() {
  // --- AC3: Strategy selection -----------------------------------------------

  test('should_select_PuntuacionMixta_when_timed', () {
    // Arrange — a timed level definition (limiteTiempo != null, numero >= 10).
    const definicion = DefinicionNivel(
      id: 1,
      numero: 10,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      umbralesEstrellas: [300, 600, 900],
      limiteTiempo: Duration(seconds: 60),
    );
    const useCase = CalcularPuntuacionUseCase();

    // Act
    final resultado = useCase.calcular(
      definicion: definicion,
      movimientos: 5,
      segundosRestantes: 30,
    );

    // Assert — timed formula: 1000 − 5·10 + 30·2 = 1010.
    expect(resultado.puntaje, 1010);
  });

  test('should_select_PuntuacionPorMovimientos_when_untimed', () {
    // Arrange — an untimed level definition (limiteTiempo is null).
    const definicion = DefinicionNivel(
      id: 2,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      umbralesEstrellas: [300, 600, 900],
      limiteTiempo: null,
    );
    const useCase = CalcularPuntuacionUseCase();

    // Act — even though segundosRestantes is provided, it must be ignored.
    final resultado = useCase.calcular(
      definicion: definicion,
      movimientos: 5,
      segundosRestantes: 30,
    );

    // Assert — untimed formula: 1000 − 5·10 = 950 (time term dropped).
    expect(resultado.puntaje, 950);
  });

  // --- AC4: Star boundary correctness ----------------------------------------

  group('should_return_1_2_3_stars_at_threshold_boundaries', () {
    const definicion = DefinicionNivel(
      id: 3,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 0,
      umbralesEstrellas: [300, 600, 900],
      limiteTiempo: null,
    );
    const useCase = CalcularPuntuacionUseCase();

    test('should_return_3_stars_when_puntaje_at_or_above_third_threshold', () {
      // Arrange — 10 moves → puntaje = 900, exactly the 3-star threshold.
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 10,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 900);
      expect(resultado.estrellas, 3);
    });

    test('should_return_2_stars_when_puntaje_at_or_above_second_threshold', () {
      // Arrange — 40 moves → puntaje = 600, exactly the 2-star threshold.
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 40,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 600);
      expect(resultado.estrellas, 2);
    });

    test('should_return_1_star_when_puntaje_at_or_above_first_threshold', () {
      // Arrange — 70 moves → puntaje = 300, exactly the 1-star threshold.
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 70,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 300);
      expect(resultado.estrellas, 1);
    });

    test('should_return_0_stars_when_puntaje_below_first_threshold', () {
      // Arrange — 80 moves → puntaje = 200, below the 1-star threshold.
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 80,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 200);
      expect(resultado.estrellas, 0);
    });

    test('should_return_3_stars_just_above_third_threshold', () {
      // Arrange — 9 moves → puntaje = 910, just above 900.
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 9,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 910);
      expect(resultado.estrellas, 3);
    });

    test('should_return_2_stars_just_below_third_threshold', () {
      // Arrange — 11 moves → puntaje = 890, just below 900.
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 11,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 890);
      expect(resultado.estrellas, 2);
    });
  });

  // --- AC5: Golden fixture parity (client/backend agree) ----------------------

  test('should_match_golden_fixture_scores', () {
    // Arrange — golden fixture data that the backend also uses.
    const fixtures = <Map<String, dynamic>>[
      {
        'id': 1,
        'numero': 10,
        'baseNivel': 1000,
        'kmov': 10,
        'ktiempo': 2,
        'umbralesEstrellas': [200, 500, 800],
        'limiteTiempo': 60,
        'movimientos': 5,
        'segundosRestantes': 30,
        'puntajeEsperado': 1010,
        'estrellasEsperadas': 3,
      },
      {
        'id': 2,
        'baseNivel': 500,
        'kmov': 10,
        'ktiempo': 1,
        'umbralesEstrellas': [100, 250, 400],
        'limiteTiempo': null,
        'movimientos': 40,
        'segundosRestantes': 0,
        'puntajeEsperado': 100,
        'estrellasEsperadas': 1,
      },
      {
        'id': 3,
        'numero': 10,
        'baseNivel': 800,
        'kmov': 15,
        'ktiempo': 3,
        'umbralesEstrellas': [300, 500, 700],
        'limiteTiempo': 90,
        'movimientos': 50,
        'segundosRestantes': 10,
        'puntajeEsperado': 80,
        'estrellasEsperadas': 0,
      },
    ];
    const useCase = CalcularPuntuacionUseCase();

    for (final fixture in fixtures) {
      final definicion = DefinicionNivel(
        id: fixture['id'] as int,
        numero: (fixture['numero'] as int?) ?? 0,
        baseNivel: fixture['baseNivel'] as int,
        kmov: fixture['kmov'] as int,
        ktiempo: fixture['ktiempo'] as int,
        umbralesEstrellas:
            (fixture['umbralesEstrellas'] as List<dynamic>).cast<int>(),
        limiteTiempo: fixture['limiteTiempo'] == null
            ? null
            : Duration(seconds: fixture['limiteTiempo'] as int),
      );

      // Act
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: fixture['movimientos'] as int,
        segundosRestantes: fixture['segundosRestantes'] as int,
      );

      // Assert
      expect(
        resultado.puntaje,
        fixture['puntajeEsperado'],
        reason: 'Level ${fixture['id']} puntaje mismatch',
      );
      expect(
        resultado.estrellas,
        fixture['estrellasEsperadas'],
        reason: 'Level ${fixture['id']} estrellas mismatch',
      );
    }
  });
}
