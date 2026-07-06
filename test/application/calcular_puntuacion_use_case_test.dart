import 'package:arrowmaze/application/use_cases/calcular_puntuacion_use_case.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 19 — Proportional star bands from `referencia` (max achievable score).
///
/// Star rating uses integer cross-multiplication to avoid float drift:
///   3★: score >= 9/10 of referencia
///   2★: score >= 2/3 of referencia
///   1★: anything below 2/3
void main() {
  // --- Strategy selection (inherited from ticket 06, unchanged) ---------------

  test('should_select_PuntuacionMixta_when_timed', () {
    const definicion = DefinicionNivel(
      id: 1,
      numero: 10,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 60),
    );
    const useCase = CalcularPuntuacionUseCase();

    final resultado = useCase.calcular(
      definicion: definicion,
      movimientos: 5,
      segundosRestantes: 30,
    );

    // Timed formula: 1000 - 5*10 + 30*2 = 1010.
    expect(resultado.puntaje, 1010);
  });

  test('should_select_PuntuacionPorMovimientos_when_untimed', () {
    const definicion = DefinicionNivel(
      id: 2,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: null,
    );
    const useCase = CalcularPuntuacionUseCase();

    final resultado = useCase.calcular(
      definicion: definicion,
      movimientos: 5,
      segundosRestantes: 30,
    );

    // Untimed formula: 1000 - 5*10 = 950 (time term dropped).
    expect(resultado.puntaje, 950);
  });

  // --- AC1: Proportional band boundaries (Ticket 19) -------------------------

  group('proportional_star_bands', () {
    // Untimed level: referencia = baseNivel = 1000.
    //   3★: score >= 900  (1000*9/10 = 900)
    //   2★: score >= 667  (ceil(1000*2/3) = 667, since 666*3 = 1998 < 2000)
    //   1★: score < 667
    const definicion = DefinicionNivel(
      id: 3,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 0,
      limiteTiempo: null,
    );
    const useCase = CalcularPuntuacionUseCase();

    test('should_return_3_stars_when_score_at_exact_9_10_of_referencia', () {
      // 10 moves => 1000 - 10*10 = 900 (exactly 9/10 of 1000).
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 10,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 900);
      expect(resultado.estrellas, 3);
    });

    test('should_return_3_stars_when_score_above_9_10_of_referencia', () {
      // 0 moves => 1000 (maximum).
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 0,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 1000);
      expect(resultado.estrellas, 3);
    });

    test('should_return_2_stars_when_score_below_9_10_but_at_or_above_2_3', () {
      // 11 moves => 1000 - 11*10 = 890 (below 900, above 667).
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 11,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 890);
      expect(resultado.estrellas, 2);
    });

    test('should_return_2_stars_at_exact_2_3_boundary', () {
      // 33 moves => 1000 - 33*10 = 670.
      // 670*3 = 2010 >= 2000 → 2★
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 33,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 670);
      expect(resultado.estrellas, 2);
    });

    test('should_return_1_star_when_score_below_2_3_of_referencia', () {
      // 34 moves => 1000 - 34*10 = 660.
      // 660*3 = 1980 < 2000 → 1★
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 34,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 660);
      expect(resultado.estrellas, 1);
    });

    test('should_return_1_star_when_score_is_zero', () {
      // 200 moves => 1000 - 200*10 = -1000, floored at 0.
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 200,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 0);
      // Minimum star rating in proportional system is 1★.
      expect(resultado.estrellas, 1);
    });

    test('should_return_1_star_when_score_is_one', () {
      // 100 moves => 1000 - 100*10 = 0 (actually 99 moves gives 10).
      // Let's use 100 for 0, 99 for 10.
      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: 100,
        segundosRestantes: 0,
      );
      expect(resultado.puntaje, 0);
      expect(resultado.estrellas, 1);
    });
  });

  // --- AC2: Near-maximum score → 3 stars ------------------------------------

  test('should_return_3_stars_when_score_near_maximum', () {
    // Timed level: baseNivel=1000, ktiempo=2, limiteTiempo=60s.
    // referencia = 1000 + 60*2 = 1120.
    // 9/10 of 1120 = 1008.
    // 0 moves, 59 seconds remaining => 1000 + 59*2 = 1118 >= 1008 → 3★
    const definicion = DefinicionNivel(
      id: 4,
      numero: 10,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 60),
    );
    const useCase = CalcularPuntuacionUseCase();

    final resultado = useCase.calcular(
      definicion: definicion,
      movimientos: 0,
      segundosRestantes: 59,
    );

    expect(resultado.puntaje, 1118);
    expect(resultado.estrellas, 3);
  });

  // --- AC4: Golden fixture parity (client/backend agree, Ticket 19) ----------

  test('should_match_golden_fixture_scores', () {
    // Golden fixtures shared with backend (Ticket 17).
    // Star counts use proportional bands from referencia:
    //
    // Fixture 1: baseNivel=1000, timed (60s), referencia=1120
    //   score=1010, 1010*10=10100 >= 1120*9=10080 → 3★
    // Fixture 2: baseNivel=500, untimed, referencia=500
    //   score=100, 100*3=300 < 500*2=1000 → 1★
    // Fixture 3: baseNivel=800, timed (90s), referencia=1070
    //   score=80, 80*3=240 < 1070*2=2140 → 1★
    const fixtures = <Map<String, dynamic>>[
      {
        'id': 1,
        'numero': 10,
        'baseNivel': 1000,
        'kmov': 10,
        'ktiempo': 2,
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
        'limiteTiempo': 90,
        'movimientos': 50,
        'segundosRestantes': 10,
        'puntajeEsperado': 80,
        'estrellasEsperadas': 1,
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
        limiteTiempo: fixture['limiteTiempo'] == null
            ? null
            : Duration(seconds: fixture['limiteTiempo'] as int),
      );

      final resultado = useCase.calcular(
        definicion: definicion,
        movimientos: fixture['movimientos'] as int,
        segundosRestantes: fixture['segundosRestantes'] as int,
      );

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
