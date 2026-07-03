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
}

class _CatalogoQueFalla implements CatalogoNiveles {
  @override
  Future<List<ResumenNivel>> listar() async => throw Exception('boom');
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
