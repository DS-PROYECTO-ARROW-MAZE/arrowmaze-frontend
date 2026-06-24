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

/// A solvable 4×4 board: arrows are length-2, heads on the border pointing
/// off-board, so all are immediately clearable in any order.
class _GeneradorSolvable extends GeneradorNivelBase {
  final List<String> ordenLlamadas;

  _GeneradorSolvable(this.ordenLlamadas);

  @override
  void poblar(Tablero tablero, ConfiguracionGeneracion config) {
    ordenLlamadas.add('poblar');
    final g = tablero as GrafoTablero;
    g.agregarTrayectoria(Trayectoria(
      id: 1,
      direccionCabeza: Direccion.arriba,
      segmentos: const [
        Posicion.en(fila: 1, columna: 0),
        Posicion.en(fila: 0, columna: 0),
      ],
    ));
    g.agregarTrayectoria(Trayectoria(
      id: 2,
      direccionCabeza: Direccion.arriba,
      segmentos: const [
        Posicion.en(fila: 1, columna: 1),
        Posicion.en(fila: 0, columna: 1),
      ],
    ));
    g.agregarTrayectoria(Trayectoria(
      id: 3,
      direccionCabeza: Direccion.izquierda,
      segmentos: const [
        Posicion.en(fila: 2, columna: 2),
        Posicion.en(fila: 2, columna: 1),
      ],
    ));
    g.agregarTrayectoria(Trayectoria(
      id: 4,
      direccionCabeza: Direccion.derecha,
      segmentos: const [
        Posicion.en(fila: 3, columna: 1),
        Posicion.en(fila: 3, columna: 2),
      ],
    ));
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

/// A generator that emits a length-1 arrow (violates the ≥2 invariant).
class _GeneradorFlechaCorta extends GeneradorNivelBase {
  @override
  void poblar(Tablero tablero, ConfiguracionGeneracion config) {
    final g = tablero as GrafoTablero;
    g.agregarTrayectoria(flecha(1, 1, 1, Direccion.arriba));
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
      final config = ConfiguracionGeneracion(filas: 4, columnas: 4);

      generador.generar(config);

      expect(ordenLlamadas, ['poblar']);
    });

    test('should_return_tablero_when_poblar_yields_solvable_board', () {
      final generador = _GeneradorSolvable([]);
      final config = ConfiguracionGeneracion(filas: 4, columnas: 4);

      final resultado = generador.generar(config);

      expect(resultado, isNotNull);
      expect(resultado, isA<Tablero>());
    });

    test('should_fail_generation_when_arrow_has_length_one', () {
      final generador = _GeneradorFlechaCorta();
      final config = ConfiguracionGeneracion(filas: 3, columnas: 3);

      final resultado = generador.generar(config);

      expect(resultado, isNull);
    });
  });
}
