import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/application/generadores/generacion_aleatoria_nivel.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collects the distinct [Trayectoria]s covering [tablero].
Set<Trayectoria> _trayectorias(Tablero tablero) {
  final vistas = <int, Trayectoria>{};
  for (var f = 0; f < tablero.filas; f++) {
    for (var c = 0; c < tablero.columnas; c++) {
      final t = tablero.trayectoriaEn(Posicion.en(fila: f, columna: c));
      if (t != null) vistas[t.id] = t;
    }
  }
  return vistas.values.toSet();
}

void main() {
  group('GeneracionAleatoriaNivel — proper puzzle generation', () {
    // A spread of dimensions (square, wide, tall, odd) and seeds.
    const tamanos = [
      [4, 4],
      [5, 5],
      [6, 6],
      [4, 6],
      [6, 4],
      [3, 5],
      [5, 3],
      [7, 7],
    ];

    for (final tam in tamanos) {
      final filas = tam[0];
      final columnas = tam[1];

      for (var semilla = 0; semilla < 6; semilla++) {
        test(
          'should_be_solvable_dense_and_bending_when_${filas}x${columnas}_seed_$semilla',
          () {
            // Arrange
            final generador = GeneracionAleatoriaNivel(semilla: semilla);
            final config =
                ConfiguracionGeneracion(filas: filas, columnas: columnas);

            // Act
            final tablero = generador.generar(config);

            // Assert — solvable: the gate only returns a board it could empty.
            expect(tablero, isNotNull,
                reason: 'gate rejected ${filas}x$columnas seed $semilla');

            // Assert — 100% density: every cell holds an arrow segment.
            for (var f = 0; f < filas; f++) {
              for (var c = 0; c < columnas; c++) {
                expect(
                  tablero!.celdaEn(Posicion.en(fila: f, columna: c)),
                  isA<CeldaFlecha>(),
                  reason: 'cell ($f,$c) is not filled',
                );
              }
            }

            final trayectorias = _trayectorias(tablero!);

            // Assert — tangled, not a single snake/stripe: several arrows, with
            // varied lengths (a band/snake layout would be uniform or single).
            expect(trayectorias.length, greaterThanOrEqualTo(2),
                reason: 'expected multiple interlocking arrows');
            final largos = trayectorias.map((t) => t.segmentos.length).toSet();
            expect(largos.length, greaterThanOrEqualTo(2),
                reason: 'arrow lengths do not vary (looks like fixed bands)');

            // Assert — continuous & bending: at least one path spans more than
            // one row AND more than one column (a straight line cannot).
            final hayCurva = trayectorias.any((t) {
              final filasUnicas = t.segmentos.map((p) => p.fila).toSet();
              final colsUnicas = t.segmentos.map((p) => p.columna).toSet();
              return filasUnicas.length > 1 && colsUnicas.length > 1;
            });
            expect(hayCurva, isTrue, reason: 'no bending path generated');
          },
        );
      }
    }
  });
}
