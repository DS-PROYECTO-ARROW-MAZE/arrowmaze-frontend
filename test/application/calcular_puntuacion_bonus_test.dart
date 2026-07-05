import 'package:arrowmaze/application/use_cases/calcular_puntuacion_use_case.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 18 — AC3: bonus levels produce no `Puntaje`/`Estrellas`;
/// [CalcularPuntuacionUseCase.calcular] returns zero score and zero stars
/// when [DefinicionNivel.esBonus] is `true`.
void main() {
  test('should_skip_scoring_when_level_is_bonus', () {
    const definicion = DefinicionNivel(
      id: 20,
      numero: 20,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 90),
      esBonus: true,
    );
    const useCase = CalcularPuntuacionUseCase();

    final resultado = useCase.calcular(
      definicion: definicion,
      movimientos: 5,
      segundosRestantes: 30,
    );

    expect(resultado.puntaje, 0);
    expect(resultado.estrellas, 0);
  });
}
