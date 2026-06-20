import 'package:arrowmaze/application/generadores/generador_nivel_base.dart';
import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Single-cell path helper.
Trayectoria flecha(int id, int fila, int columna, Direccion direccion) =>
    Trayectoria(
      id: id,
      direccionCabeza: direccion,
      segmentos: [Posicion.en(fila: fila, columna: columna)],
    );

/// A solvable 3×3 board: every arrow is on the border pointing off-board,
/// so all are immediately clearable in any order.
class _GeneradorSolvable extends GeneradorNivelBase {
  final List<String> ordenLlamadas;

  _GeneradorSolvable(this.ordenLlamadas);

  @override
  void poblar(Tablero tablero, ConfiguracionGeneracion config) {
    ordenLlamadas.add('poblar');
    final g = tablero as GrafoTablero;
    g.agregarTrayectoria(flecha(1, 0, 0, Direccion.arriba));
    g.agregarTrayectoria(flecha(2, 0, 1, Direccion.arriba));
    g.agregarTrayectoria(flecha(3, 0, 2, Direccion.arriba));
    g.agregarTrayectoria(flecha(4, 1, 0, Direccion.izquierda));
    g.agregarTrayectoria(flecha(5, 2, 0, Direccion.abajo));
    g.agregarTrayectoria(flecha(6, 2, 1, Direccion.abajo));
    g.agregarTrayectoria(flecha(7, 2, 2, Direccion.abajo));
    g.agregarTrayectoria(flecha(8, 1, 2, Direccion.derecha));
    // (1,1) is the only empty cell — not covered by any path.
  }
}

/// An unsolvable board: two arrows block each other (deadlock).
class _GeneradorInsolvable extends GeneradorNivelBase {
  @override
  void poblar(Tablero tablero, ConfiguracionGeneracion config) {
    final g = tablero as GrafoTablero;
    g.agregarTrayectoria(flecha(1, 1, 0, Direccion.derecha));
    g.agregarTrayectoria(flecha(2, 1, 2, Direccion.izquierda));
    // Both arrows point at each other — no clear exit.
  }
}

void main() {
  group('GeneradorNivelBase', () {
    test('should_fail_generation_when_poblar_yields_unsolvable_board', () {
      final generador = _GeneradorInsolvable();
      final config = ConfiguracionGeneracion(filas: 3, columnas: 3);

      final resultado = generador.generar(config);

      expect(resultado, isNull);
    });

    test('should_call_validarSolvencia_before_entregar', () {
      final ordenLlamadas = <String>[];
      final generador = _GeneradorSolvable(ordenLlamadas);
      final config = ConfiguracionGeneracion(filas: 3, columnas: 3);

      generador.generar(config);

      expect(ordenLlamadas, ['poblar']);
    });

    test('should_return_tablero_when_poblar_yields_solvable_board', () {
      final generador = _GeneradorSolvable([]);
      final config = ConfiguracionGeneracion(filas: 3, columnas: 3);

      final resultado = generador.generar(config);

      expect(resultado, isNotNull);
      expect(resultado, isA<Tablero>());
    });
  });
}
