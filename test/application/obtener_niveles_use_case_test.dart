import 'package:arrowmaze/application/ports/catalogo_niveles.dart';
import 'package:arrowmaze/application/ports/consulta_progreso_local.dart';
import 'package:arrowmaze/application/use_cases/nivel_con_estado.dart';
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

    // Ticket 32 (AC2) — the monotonic-unlock invariant. A completed-set with a
    // hole (here: 1‑8 minus id 5, the reported "L6 padlock while L7/L8 have
    // stars" case) must never render a locked level *before* an unlocked one.
    test('should_never_lock_a_level_before_an_unlocked_one', () async {
      // Arrange — eight levels; every id completed except a middle one (5).
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(_ochoNiveles),
        progreso: _ProgresoFake(completados: const {1, 2, 3, 4, 6, 7, 8}),
      );

      // Act
      final niveles = await useCase.ejecutar();

      // Assert — for every unlocked level, all earlier levels are unlocked too.
      _expectMonotonicUnlock(niveles);
      // And specifically the reported case: level 6 is not phantom-locked.
      expect(niveles.firstWhere((n) => n.resumen.id == 6).desbloqueado, isTrue);
    });

    test('should_keep_stars_from_real_records_when_filling_unlock_holes',
        () async {
      // Arrange — hole at 5: it has no record, but 6 does. Saturating the unlock
      // set must not invent completion/stars for the gap level.
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(_ochoNiveles),
        progreso: _ProgresoFake(
          completados: const {1, 2, 3, 4, 6, 7, 8},
          estrellas: const {6: 3},
        ),
      );

      // Act
      final niveles = await useCase.ejecutar();

      // Assert — level 5 is unlocked but not marked completed (no phantom star).
      final nivel5 = niveles.firstWhere((n) => n.resumen.id == 5);
      expect(nivel5.desbloqueado, isTrue);
      expect(nivel5.completado, isFalse);
      expect(nivel5.estrellas, 0);
      // Level 6 keeps its real stars.
      final nivel6 = niveles.firstWhere((n) => n.resumen.id == 6);
      expect(nivel6.completado, isTrue);
      expect(nivel6.estrellas, 3);
    });
  });
}

/// Reusable invariant: in a rendered catalog, an unlocked level implies every
/// earlier level (lower id) is unlocked (Ticket 32, AC2).
void _expectMonotonicUnlock(List<NivelConEstado> niveles) {
  final ordenados = [...niveles]
    ..sort((a, b) => a.resumen.id.compareTo(b.resumen.id));
  var vistoBloqueado = false;
  for (final nivel in ordenados) {
    if (!nivel.desbloqueado) {
      vistoBloqueado = true;
    } else if (vistoBloqueado) {
      fail('Level ${nivel.resumen.id} is unlocked but an earlier level is '
          'locked — monotonic-unlock invariant violated.');
    }
  }
}

const _ochoNiveles = [
  ResumenNivel(id: 1, nombre: 'One', dificultad: Dificultad.facil),
  ResumenNivel(id: 2, nombre: 'Two', dificultad: Dificultad.facil),
  ResumenNivel(id: 3, nombre: 'Three', dificultad: Dificultad.medio),
  ResumenNivel(id: 4, nombre: 'Four', dificultad: Dificultad.medio),
  ResumenNivel(id: 5, nombre: 'Five', dificultad: Dificultad.medio),
  ResumenNivel(id: 6, nombre: 'Six', dificultad: Dificultad.dificil),
  ResumenNivel(id: 7, nombre: 'Seven', dificultad: Dificultad.dificil),
  ResumenNivel(id: 8, nombre: 'Eight', dificultad: Dificultad.dificil),
];

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

  @override
  Future<int> obtenerCantidadTotal() async => _niveles.length;

  @override
  Future<ResumenNivel> obtenerPorIndice(int indice) async =>
      _niveles.firstWhere((r) => r.id == indice);
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
