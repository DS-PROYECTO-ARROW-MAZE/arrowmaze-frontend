import 'package:arrowmaze/application/ports/catalogo_niveles.dart';
import 'package:arrowmaze/application/ports/consulta_progreso_local.dart';
import 'package:arrowmaze/application/use_cases/obtener_niveles_use_case.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
import 'package:arrowmaze/domain/niveles/resumen_nivel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 13 — ObtenerNivelesUseCase joins catalog + progress + unlock rule
/// (DM §10.3). Driven through fakes — no assets, no shared_preferences.
void main() {
  group('ObtenerNivelesUseCase', () {
    test('should_unlock_only_first_level_when_no_progress', () async {
      // Arrange — three levels, nothing completed.
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(_tresNiveles),
        progreso: _ProgresoFake(completados: const {}),
      );

      // Act
      final niveles = await useCase.ejecutar();

      // Assert — sequential gate: only level 1 is playable.
      expect(niveles.map((n) => n.desbloqueado), [true, false, false]);
      expect(niveles.every((n) => !n.completado), isTrue);
      expect(niveles.every((n) => n.estrellas == 0), isTrue);
    });

    test('should_unlock_next_and_carry_stars_when_level_completed', () async {
      // Arrange — level 1 cleared with 2 stars.
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(_tresNiveles),
        progreso: _ProgresoFake(
          completados: const {1},
          estrellas: const {1: 2},
        ),
      );

      // Act
      final niveles = await useCase.ejecutar();

      // Assert — level 2 unlocks, level 1 shows its stars, level 3 stays locked.
      expect(niveles[0].completado, isTrue);
      expect(niveles[0].estrellas, 2);
      expect(niveles[1].desbloqueado, isTrue);
      expect(niveles[1].completado, isFalse);
      expect(niveles[2].desbloqueado, isFalse);
    });

    test('should_mark_completed_even_when_cleared_with_zero_stars', () async {
      // Arrange — level 1 completed but earned 0 stars.
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(_tresNiveles),
        progreso: _ProgresoFake(
          completados: const {1},
          estrellas: const {1: 0},
        ),
      );

      // Act
      final niveles = await useCase.ejecutar();

      // Assert — completion unlocks the next level despite 0 stars.
      expect(niveles[0].completado, isTrue);
      expect(niveles[0].estrellas, 0);
      expect(niveles[1].desbloqueado, isTrue);
    });
  });
}

const _tresNiveles = [
  ResumenNivel(id: 1, nombre: 'One', dificultad: Dificultad.facil),
  ResumenNivel(id: 2, nombre: 'Two', dificultad: Dificultad.medio),
  ResumenNivel(id: 3, nombre: 'Three', dificultad: Dificultad.dificil),
];

class _CatalogoFake implements CatalogoNiveles {
  _CatalogoFake(this._niveles);

  final List<ResumenNivel> _niveles;

  @override
  Future<List<ResumenNivel>> listar() async => _niveles;
}

class _ProgresoFake implements ConsultaProgresoLocal {
  _ProgresoFake({required this.completados, this.estrellas = const {}});

  final Set<int> completados;
  final Map<int, int> estrellas;

  @override
  Future<Set<int>> nivelesCompletados() async => completados;

  @override
  Future<int> mejorEstrellas(int idNivel) async => estrellas[idNivel] ?? 0;

  @override
  Future<void> registrarCompletado({
    required int idNivel,
    required int estrellas,
  }) async {}

  @override
  Future<void> limpiar() async {}
}
