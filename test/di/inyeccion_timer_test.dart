import 'package:arrowmaze/di/inyeccion.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
import 'package:flutter_test/flutter_test.dart';

/// The per-level timer rule lives in the composition root: a countdown exists
/// **only** on medium and hard levels. Easy levels are untimed (no clock at all).
void main() {
  group('Inyeccion.limiteTiempoPorDificultad', () {
    test('should_have_no_timer_when_level_is_easy', () {
      expect(Inyeccion.limiteTiempoPorDificultad(Dificultad.facil), isNull);
    });

    test('should_have_a_timer_when_level_is_medium', () {
      final limite = Inyeccion.limiteTiempoPorDificultad(Dificultad.medio);
      expect(limite, isNotNull);
      expect(limite! > Duration.zero, isTrue);
    });

    test('should_have_a_timer_when_level_is_hard', () {
      final limite = Inyeccion.limiteTiempoPorDificultad(Dificultad.dificil);
      expect(limite, isNotNull);
      expect(limite! > Duration.zero, isTrue);
    });
  });
}
