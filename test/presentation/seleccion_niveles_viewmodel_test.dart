import 'package:arrowmaze/application/ports/catalogo_niveles.dart';
import 'package:arrowmaze/application/ports/consulta_progreso_local.dart';
import 'package:arrowmaze/application/use_cases/obtener_niveles_use_case.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
import 'package:arrowmaze/domain/niveles/resumen_nivel.dart';
import 'package:arrowmaze/presentation/viewmodels/seleccion_niveles_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 13 — SeleccionNivelesViewModel maps use-case output to card state
/// (DM §10.4).
void main() {
  group('SeleccionNivelesViewModel', () {
    test('should_expose_levels_with_lock_and_star_state_when_loaded', () async {
      // Arrange — level 1 cleared with 3 stars; 2 known levels.
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(const [
          ResumenNivel(id: 1, nombre: 'One', dificultad: Dificultad.facil),
          ResumenNivel(id: 2, nombre: 'Two', dificultad: Dificultad.medio),
        ]),
        progreso: _ProgresoFake(completados: const {1}, estrellas: const {1: 3}),
      );
      final vm = SeleccionNivelesViewModel(obtenerNiveles: useCase);

      // Act
      await vm.cargar();

      // Assert
      final niveles = vm.estado.niveles;
      expect(vm.estado.cargando, isFalse);
      expect(niveles, hasLength(2));
      expect(niveles[0].completado, isTrue);
      expect(niveles[0].estrellas, 3);
      expect(niveles[1].desbloqueado, isTrue);
      expect(niveles[1].completado, isFalse);
    });

    /// Ticket 36 — the card model must carry `es3D` through unchanged, so the
    /// View can show "3D" instead of a difficulty label without re-deriving
    /// it from anything (single source of truth: the catalog summary).
    test('should_expose_es3D_when_a_level_is_a_depth_aware_board', () async {
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(const [
          ResumenNivel(id: 1, nombre: 'One', dificultad: Dificultad.facil),
          ResumenNivel(
            id: 16,
            nombre: '3D Cube',
            dificultad: Dificultad.facil,
            es3D: true,
          ),
        ]),
        progreso: _ProgresoFake(completados: const {}),
      );
      final vm = SeleccionNivelesViewModel(obtenerNiveles: useCase);

      await vm.cargar();

      final niveles = vm.estado.niveles;
      expect(niveles.firstWhere((n) => n.id == 1).es3D, isFalse);
      expect(niveles.firstWhere((n) => n.id == 16).es3D, isTrue);
    });

    test('should_expose_error_when_use_case_throws', () async {
      // Arrange — a catalog that fails.
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoQueFalla(),
        progreso: _ProgresoFake(completados: const {}),
      );
      final vm = SeleccionNivelesViewModel(obtenerNiveles: useCase);

      // Act
      await vm.cargar();

      // Assert
      expect(vm.estado.cargando, isFalse);
      expect(vm.estado.niveles, isEmpty);
      expect(vm.estado.mensajeError, isNotNull);
    });

    /// Ticket 32 AC1 — the exact reported regression: a returning player whose
    /// history reaches Levels 7–8 must see every earlier level unlocked, with no
    /// padlock on Level 6 (the completed-set arrives with a hole at id 5).
    test('should_render_level6_unlocked_when_levels_7_and_8_are_completed',
        () async {
      // Arrange — 1‑8 completed except the middle id 5 (mirrors a lossy restore).
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(const [
          ResumenNivel(id: 1, nombre: 'One', dificultad: Dificultad.facil),
          ResumenNivel(id: 2, nombre: 'Two', dificultad: Dificultad.facil),
          ResumenNivel(id: 3, nombre: 'Three', dificultad: Dificultad.medio),
          ResumenNivel(id: 4, nombre: 'Four', dificultad: Dificultad.medio),
          ResumenNivel(id: 5, nombre: 'Five', dificultad: Dificultad.medio),
          ResumenNivel(id: 6, nombre: 'Six', dificultad: Dificultad.dificil),
          ResumenNivel(id: 7, nombre: 'Seven', dificultad: Dificultad.dificil),
          ResumenNivel(id: 8, nombre: 'Eight', dificultad: Dificultad.dificil),
        ]),
        progreso: _ProgresoFake(
          completados: const {1, 2, 3, 4, 6, 7, 8},
          estrellas: const {7: 3, 8: 2},
        ),
      );
      final vm = SeleccionNivelesViewModel(obtenerNiveles: useCase);

      // Act
      await vm.cargar();

      // Assert — no padlock precedes an unlocked level; Level 6 is playable.
      final niveles = vm.estado.niveles;
      final nivel6 = niveles.firstWhere((n) => n.id == 6);
      expect(nivel6.desbloqueado, isTrue);
      // Levels 7 and 8 still carry their stars.
      expect(niveles.firstWhere((n) => n.id == 7).estrellas, 3);
      expect(niveles.firstWhere((n) => n.id == 8).estrellas, 2);
      // Every level up to the highest completed is unlocked (monotonic).
      for (final nivel in niveles.where((n) => n.id <= 8)) {
        expect(nivel.desbloqueado, isTrue,
            reason: 'Level ${nivel.id} must not be locked before an unlocked one.');
      }
    });

    /// Ticket 24 AC1 — re-calling `cargar()` (triggered by every View
    /// appearance, including Back-nav) must re-read progression so the UI is
    /// never stale. This test mutates progression between loads.
    test('should_reload_progression_when_view_reappears', () async {
      // Arrange — progression starts with only level 1 completed.
      final progreso = _ProgresoMutable();
      await progreso.registrarCompletado(idNivel: 1, estrellas: 2);
      final useCase = ObtenerNivelesUseCase(
        catalogo: _CatalogoFake(const [
          ResumenNivel(id: 1, nombre: 'One', dificultad: Dificultad.facil),
          ResumenNivel(id: 2, nombre: 'Two', dificultad: Dificultad.medio),
          ResumenNivel(id: 3, nombre: 'Three', dificultad: Dificultad.dificil),
        ]),
        progreso: progreso,
      );
      final vm = SeleccionNivelesViewModel(obtenerNiveles: useCase);

      // Act — first load.
      await vm.cargar();

      // Assert — level 1 complete, level 2 unlocked, level 3 locked.
      expect(vm.estado.niveles[0].completado, isTrue);
      expect(vm.estado.niveles[0].estrellas, 2);
      expect(vm.estado.niveles[1].desbloqueado, isTrue);
      expect(vm.estado.niveles[2].desbloqueado, isFalse);

      // Arrange (2) — simulate player clears level 2 (Back-nav comes later).
      await progreso.registrarCompletado(idNivel: 2, estrellas: 1);

      // Act (2) — reload (as if Back-nav or Retry→Menu triggered).
      await vm.cargar();

      // Assert — level 3 now unlocked, level 2 shows its stars.
      expect(vm.estado.niveles[0].completado, isTrue);
      expect(vm.estado.niveles[0].estrellas, 2);
      expect(vm.estado.niveles[1].completado, isTrue);
      expect(vm.estado.niveles[1].estrellas, 1);
      expect(vm.estado.niveles[2].desbloqueado, isTrue);
    });
  });
}

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

class _CatalogoQueFalla implements CatalogoNiveles {
  @override
  Future<List<ResumenNivel>> listar() async => throw Exception('boom');

  @override
  Future<int> obtenerCantidadTotal() async => throw Exception('boom');

  @override
  Future<ResumenNivel> obtenerPorIndice(int indice) async =>
      throw Exception('boom');
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

/// Mutable progression fake for the back-nav refresh test (Ticket 24 AC1).
/// `registrarCompletado` actually writes so a subsequent `mejorEstrellas` / 
/// `nivelesCompletados` yields fresh values.
class _ProgresoMutable implements ConsultaProgresoLocal {
  final Map<int, int> _data = {};

  @override
  Future<Set<int>> nivelesCompletados() async => _data.keys.toSet();

  @override
  Future<int> mejorEstrellas(int idNivel) async => _data[idNivel] ?? 0;

  @override
  Future<void> registrarCompletado({
    required int idNivel,
    required int estrellas,
  }) async {
    final actual = _data[idNivel] ?? -1;
    if (estrellas > actual) {
      _data[idNivel] = estrellas;
    }
  }

  @override
  Future<void> limpiar() async => _data.clear();
}
