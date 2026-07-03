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
