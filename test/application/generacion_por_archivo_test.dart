import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/application/generadores/generacion_por_archivo_nivel.dart';
import 'package:arrowmaze/application/ports/cargador_nivel.dart';
import 'package:arrowmaze/application/ports/definicion_nivel_dto.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:flutter_test/flutter_test.dart';

class _CargadorFalsoSolvable implements CargadorNivel {
  @override
  Future<DefinicionNivelDto> cargar(int id) async {
    return DefinicionNivelDto(
      id: id,
      filas: 4,
      columnas: 4,
      trayectorias: [
        {'id': 1, 'head': 'UP', 'cells': [{'row': 1, 'col': 0}, {'row': 0, 'col': 0}]},
        {'id': 2, 'head': 'UP', 'cells': [{'row': 1, 'col': 1}, {'row': 0, 'col': 1}]},
        {'id': 3, 'head': 'DOWN', 'cells': [{'row': 2, 'col': 2}, {'row': 3, 'col': 2}]},
        {'id': 4, 'head': 'DOWN', 'cells': [{'row': 2, 'col': 3}, {'row': 3, 'col': 3}]},
      ],
      celdas: const <Map<String, dynamic>>[],
    );
  }
}

/// A loader whose DTO contains a length-1 arrow (violates the ≥2 invariant).
class _CargadorFalsoFlechaCorta implements CargadorNivel {
  @override
  Future<DefinicionNivelDto> cargar(int id) async {
    return DefinicionNivelDto(
      id: id,
      filas: 3,
      columnas: 3,
      trayectorias: [
        {'id': 1, 'head': 'UP', 'cells': [{'row': 1, 'col': 1}]},
      ],
      celdas: const <Map<String, dynamic>>[],
    );
  }
}

class _CargadorFalsoInsolvable implements CargadorNivel {
  @override
  Future<DefinicionNivelDto> cargar(int id) async {
    return DefinicionNivelDto(
      id: id,
      filas: 3,
      columnas: 3,
      trayectorias: [
        {'id': 1, 'head': 'RIGHT', 'cells': [{'row': 1, 'col': 0}]},
        {'id': 2, 'head': 'LEFT', 'cells': [{'row': 1, 'col': 2}]},
      ],
      celdas: const <Map<String, dynamic>>[],
    );
  }
}

/// A loader whose DTO carries `layers: 2` and per-cell `layer` fields — a
/// cross-layer bending path (mirrors `level_3d_test_02`) that exits clear.
class _CargadorFalso3DSolvable implements CargadorNivel {
  @override
  Future<DefinicionNivelDto> cargar(int id) async {
    return DefinicionNivelDto(
      id: id,
      filas: 1,
      columnas: 2,
      layers: 2,
      trayectorias: [
        {
          'id': 1,
          'head': 'FORWARD',
          'cells': [
            {'row': 0, 'col': 0, 'layer': 0},
            {'row': 0, 'col': 1, 'layer': 0},
            {'row': 0, 'col': 1, 'layer': 1},
          ],
        },
      ],
      celdas: const <Map<String, dynamic>>[],
    );
  }
}

/// A loader whose DTO carries a 3-layer mutual cross-layer block (mirrors
/// `level_3d_test_03`) — must be rejected by the solvability gate.
class _CargadorFalso3DInsolvable implements CargadorNivel {
  @override
  Future<DefinicionNivelDto> cargar(int id) async {
    return DefinicionNivelDto(
      id: id,
      filas: 1,
      columnas: 2,
      layers: 3,
      trayectorias: [
        {
          'id': 1,
          'head': 'FORWARD',
          'cells': [
            {'row': 0, 'col': 0, 'layer': 0},
            {'row': 0, 'col': 0, 'layer': 1},
          ],
        },
        {
          'id': 2,
          'head': 'BACKWARD',
          'cells': [
            {'row': 0, 'col': 1, 'layer': 2},
            {'row': 0, 'col': 0, 'layer': 2},
          ],
        },
      ],
      celdas: const <Map<String, dynamic>>[],
    );
  }
}

void main() {
  group('GeneracionPorArchivoNivel', () {
    test('should_validate_solvability_before_render_when_loading_by_id', () async {
      final cargador = _CargadorFalsoSolvable();
      final generador = GeneracionPorArchivoNivel(cargador: cargador);
      final config = ConfiguracionGeneracion(filas: 3, columnas: 3);

      final resultado = await generador.generarAsync(config, idNivel: 1);

      expect(resultado, isNotNull);
      expect(resultado, isA<Tablero>());
    });

    test('should_return_null_when_loaded_level_is_unsolvable', () async {
      final cargador = _CargadorFalsoInsolvable();
      final generador = GeneracionPorArchivoNivel(cargador: cargador);
      final config = ConfiguracionGeneracion(filas: 3, columnas: 3);

      final resultado = await generador.generarAsync(config, idNivel: 1);

      expect(resultado, isNull);
    });

    test('should_reject_loaded_board_when_it_has_length_one_arrow', () async {
      final cargador = _CargadorFalsoFlechaCorta();
      final generador = GeneracionPorArchivoNivel(cargador: cargador);
      final config = ConfiguracionGeneracion(filas: 3, columnas: 3);

      final resultado = await generador.generarAsync(config, idNivel: 1);

      expect(resultado, isNull);
    });

    test(
        'should_validate_solvability_through_unmodified_template_when_loading_a_3d_level',
        () async {
      // AC1 — a level with layers > 1 runs validarSolvencia through the
      // unmodified GeneradorNivelBase template before it reaches the ViewModel.
      final cargador = _CargadorFalso3DSolvable();
      final generador = GeneracionPorArchivoNivel(cargador: cargador);
      final config = ConfiguracionGeneracion(filas: 0, columnas: 0);

      final resultado = await generador.generarAsync(config, idNivel: 9002);

      expect(resultado, isNotNull);
      expect(resultado!.profundo, 2);
    });

    test('should_reject_the_intentionally_unsolvable_3d_level', () async {
      // AC1/AC7 — an unsolvable 3D board is never handed to the ViewModel.
      final cargador = _CargadorFalso3DInsolvable();
      final generador = GeneracionPorArchivoNivel(cargador: cargador);
      final config = ConfiguracionGeneracion(filas: 0, columnas: 0);

      final resultado = await generador.generarAsync(config, idNivel: 9003);

      expect(resultado, isNull);
    });
  });
}
