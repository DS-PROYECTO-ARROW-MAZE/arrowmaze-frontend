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
      filas: 3,
      columnas: 3,
      trayectorias: [
        {'id': 1, 'head': 'UP', 'cells': [{'row': 0, 'col': 0}]},
        {'id': 2, 'head': 'UP', 'cells': [{'row': 0, 'col': 1}]},
        {'id': 3, 'head': 'UP', 'cells': [{'row': 0, 'col': 2}]},
        {'id': 4, 'head': 'LEFT', 'cells': [{'row': 1, 'col': 0}]},
        {'id': 5, 'head': 'DOWN', 'cells': [{'row': 2, 'col': 0}]},
        {'id': 6, 'head': 'DOWN', 'cells': [{'row': 2, 'col': 1}]},
        {'id': 7, 'head': 'DOWN', 'cells': [{'row': 2, 'col': 2}]},
        {'id': 8, 'head': 'RIGHT', 'cells': [{'row': 1, 'col': 2}]},
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
  });
}
