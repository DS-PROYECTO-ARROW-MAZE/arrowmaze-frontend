import 'package:arrowmaze/application/generadores/generacion_por_archivo_nivel.dart';
import 'package:arrowmaze/application/ports/cargador_nivel.dart';
import 'package:arrowmaze/application/ports/definicion_nivel_dto.dart';
import 'package:arrowmaze/presentation/viewmodels/seleccion_nivel_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _CargadorMock implements CargadorNivel {
  final DefinicionNivelDto Function(int id) _factory;

  _CargadorMock(this._factory);

  @override
  Future<DefinicionNivelDto> cargar(int id) async => _factory(id);
}

void main() {
  group('SeleccionNivelViewModel', () {
    test('should_expose_initial_state_as_not_loading', () {
      final cargador = _CargadorMock((_) => DefinicionNivelDto(
        id: 1, filas: 3, columnas: 3,
        trayectorias: [], celdas: [],
      ));
      final generador = GeneracionPorArchivoNivel(cargador: cargador);
      final vm = SeleccionNivelViewModel(generadorArchivo: generador);
      vm.inicializar();

      expect(vm.estado.cargando, isFalse);
      expect(vm.estado.tablero, isNull);
      expect(vm.estado.mensajeError, isNull);
    });

    test('should_set_cargando_during_load_and_return_tablero_when_solvable',
        () async {
      final cargador = _CargadorMock((_) => DefinicionNivelDto(
        id: 1,
        filas: 3,
        columnas: 3,
        trayectorias: [
          {'id': 1, 'head': 'UP', 'cells': [
            {'row': 0, 'col': 0},
          ]},
          {'id': 2, 'head': 'RIGHT', 'cells': [
            {'row': 1, 'col': 0},
          ]},
          {'id': 3, 'head': 'DOWN', 'cells': [
            {'row': 2, 'col': 0},
          ]},
        ],
        celdas: const [],
      ));
      final generador = GeneracionPorArchivoNivel(cargador: cargador);
      final vm = SeleccionNivelViewModel(generadorArchivo: generador);
      vm.inicializar();

      final futuro = vm.cargarNivel(1);

      expect(vm.estado.cargando, isTrue);
      expect(vm.estado.tablero, isNull);

      await futuro;

      expect(vm.estado.cargando, isFalse);
      expect(vm.estado.tablero, isNotNull);
      expect(vm.estado.mensajeError, isNull);
    });

    test('should_set_error_when_loaded_level_is_unsolvable', () async {
      final cargador = _CargadorMock((_) => DefinicionNivelDto(
        id: 1,
        filas: 3,
        columnas: 3,
        trayectorias: [
          {'id': 1, 'head': 'RIGHT', 'cells': [
            {'row': 1, 'col': 0},
          ]},
          {'id': 2, 'head': 'LEFT', 'cells': [
            {'row': 1, 'col': 2},
          ]},
        ],
        celdas: const [],
      ));
      final generador = GeneracionPorArchivoNivel(cargador: cargador);
      final vm = SeleccionNivelViewModel(generadorArchivo: generador);
      vm.inicializar();

      await vm.cargarNivel(1);

      expect(vm.estado.cargando, isFalse);
      expect(vm.estado.tablero, isNull);
      expect(vm.estado.mensajeError, isNotNull);
    });
  });
}
