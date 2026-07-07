import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/application/generadores/generacion_aleatoria_nivel.dart';
import 'package:arrowmaze/application/generadores/generador_nivel_base.dart'
    show minLongitudFlecha;
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/niveles/perfil_dificultad.dart';
import 'package:arrowmaze/domain/niveles/repertorio_formas.dart';
import 'package:arrowmaze/domain/solver.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 31 — the generator must produce **mask-respecting** shaped boards for
/// every shape at every raised size, including the thin shapes (star) and the
/// large 9×9 grids where the ticket-23 carver strands. No arrow may lie on an
/// absent cell, every playable cell is filled, no arrow is length-1, and the
/// board is solvable.
/// The unit step (row delta, col delta) from [a] to the adjacent [b].
({int df, int dc}) _paso(Posicion a, Posicion b) =>
    (df: b.fila - a.fila, dc: b.columna - a.columna);

void main() {
  group('GeneracionAleatoriaNivel — mask-respecting fill (Ticket 31)', () {
    for (var indice = 1; indice <= 15; indice++) {
      test('should_fill_only_the_shape_and_stay_solvable_for_index_$indice',
          () {
        // Arrange
        final perfil = PerfilDificultad.para(indice);
        final mascara = RepertorioFormas().formaParaIndice(indice);
        final ausentes = mascara.ausentes(perfil.filas, perfil.columnas);
        final config = ConfiguracionGeneracion(
          filas: perfil.filas,
          columnas: perfil.columnas,
          ausentes: ausentes,
        );
        final generador = GeneracionAleatoriaNivel(semilla: indice);

        // Act
        final tablero = generador.generar(config) as GrafoTablero?;

        // Assert — a board was produced.
        expect(tablero, isNotNull,
            reason: 'index $indice (${perfil.filas}x${perfil.columnas}, '
                '${mascara.nombre}) must produce a board');
        final t = tablero!;

        // Assert — absent cells are void; every playable cell is filled.
        final trayectorias = <int, Trayectoria>{};
        for (var f = 0; f < perfil.filas; f++) {
          for (var c = 0; c < perfil.columnas; c++) {
            final pos = Posicion.en(fila: f, columna: c);
            if (ausentes.contains(pos)) {
              expect(t.celdaEn(pos), isA<CeldaAusente>(),
                  reason: 'absent ($f,$c) must be void for ${mascara.nombre}');
            } else {
              expect(t.celdaEn(pos), isA<CeldaFlecha>(),
                  reason: 'playable ($f,$c) must be filled for ${mascara.nombre}');
              final tr = t.trayectoriaEn(pos);
              if (tr != null) trayectorias[tr.id] = tr;
            }
          }
        }

        // Assert — no arrow leaks onto an absent cell, and none is length-1.
        for (final tr in trayectorias.values) {
          expect(tr.segmentos.length, greaterThanOrEqualTo(minLongitudFlecha),
              reason: 'arrow ${tr.id} too short in ${mascara.nombre}');
          for (final seg in tr.segmentos) {
            expect(ausentes.contains(seg), isFalse,
                reason: 'arrow ${tr.id} leaks onto absent $seg '
                    'in ${mascara.nombre}');
          }
        }

        // Assert — arrows fire in varied directions, not all the same way (the
        // whole point of a puzzle: a board of all-UP arrows is trivial).
        final direcciones =
            trayectorias.values.map((t) => t.direccionCabeza).toSet();
        expect(direcciones.length, greaterThanOrEqualTo(2),
            reason: '${mascara.nombre} arrows must not all point the same way');

        // Assert — paths wind: at least one arrow turns twice or more along its
        // *body* (an L/zig-zag), not just a straight line with a bent tip.
        var maxGiros = 0;
        for (final t in trayectorias.values) {
          final segs = t.segmentos;
          var giros = 0;
          for (var i = 1; i < segs.length - 1; i++) {
            final a = _paso(segs[i - 1], segs[i]);
            final b = _paso(segs[i], segs[i + 1]);
            if (a != b) giros++;
          }
          if (giros > maxGiros) maxGiros = giros;
        }
        expect(maxGiros, greaterThanOrEqualTo(2),
            reason: '${mascara.nombre} arrows should zig-zag with multiple '
                'turns in the body, not run straight');

        // Assert — solvable on an independent copy (Solver mutates).
        final copia = GrafoTablero.desde(
          filas: perfil.filas,
          columnas: perfil.columnas,
          trayectorias: trayectorias.values.toList(),
          ausentes: ausentes,
        );
        expect(Solver.esSolvable(copia), isTrue,
            reason: '${mascara.nombre} board must be solvable');
      });
    }
  });
}
