import 'package:arrowmaze/application/generadores/generador_nivel_base.dart'
    show minLongitudFlecha;
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/niveles/repertorio_formas.dart';
import 'package:arrowmaze/domain/solver.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/generador_catalogo.dart';

/// Ticket 31 — retrofit shape-mask rotation + raised 7×7 grid floor onto the
/// authored catalog. These tests exercise the offline generation tool directly
/// (deterministic, Flutter-free), before any asset is written.
void main() {
  group('generador_catalogo — authored catalog generation', () {
    test('should_assign_shape_by_rotation_when_iterating_authored_numeros', () {
      // AC1 — the tool consumes ticket 23's RepertorioFormas as the single
      // source of truth for shape order; it never re-defines the repertoire.
      final repertorio = RepertorioFormas();
      for (var numero = 1; numero <= totalNivelesCatalogo; numero++) {
        expect(
          formaDeNivel(numero).nombre,
          repertorio.formaParaIndice(numero).nombre,
          reason: 'level $numero shape must follow RepertorioFormas',
        );
      }

      // And the concrete rotation starting at Level 1.
      expect(formaDeNivel(1).nombre, 'Cuadrado');
      expect(formaDeNivel(2).nombre, 'Corazón');
      expect(formaDeNivel(3).nombre, 'Triángulo');
      expect(formaDeNivel(4).nombre, 'Cruz');
      expect(formaDeNivel(5).nombre, 'Estrella');
      expect(formaDeNivel(6).nombre, 'Cuadrado');
    });

    test('should_ramp_grid_size_aggressively_when_starting_from_7x7_floor', () {
      // Level 1 sits on the raised 7×7 floor (PRD §12 req 2)…
      expect(perfilNivel(1).lado, 7, reason: 'floor');
      // …no authored level is smaller than the floor…
      for (var numero = 1; numero <= totalNivelesCatalogo; numero++) {
        expect(perfilNivel(numero).lado, greaterThanOrEqualTo(7),
            reason: 'level $numero below floor');
      }
      // …the grid grows strictly every level (aggressive difficulty ramp)…
      for (var numero = 2; numero <= totalNivelesCatalogo; numero++) {
        expect(perfilNivel(numero).lado,
            greaterThan(perfilNivel(numero - 1).lado),
            reason: 'level $numero must be larger than ${numero - 1}');
      }
      // …and the hardest level is far beyond a 9×9.
      expect(perfilNivel(totalNivelesCatalogo).lado, greaterThan(9),
          reason: 'the last level must dwarf a 9×9');
    });

    test(
        'should_produce_solvable_masked_board_with_no_length_1_arrow_when_iterating_authored_levels',
        () {
      // AC4 — every regenerated board is solvable and free of length-1 arrows.
      for (var numero = 1; numero <= totalNivelesCatalogo; numero++) {
        final json = generarNivelJson(numero);

        // No length-1 arrow: group serialized arrow cells by trajectory id.
        final porId = <int, int>{};
        for (final celda in (json['cells'] as List).cast<Map<String, dynamic>>()) {
          final id = celda['id'] as int;
          porId[id] = (porId[id] ?? 0) + 1;
        }
        for (final entry in porId.entries) {
          expect(entry.value, greaterThanOrEqualTo(minLongitudFlecha),
              reason: 'level $numero trajectory ${entry.key} is too short');
        }

        // Solvable: reconstruct the board exactly the runtime loader will and
        // greedily clear it.
        final tablero = construirTablero(json);
        expect(Solver.esSolvable(tablero), isTrue,
            reason: 'level $numero must be solvable');
      }
    });

    test('should_omit_absent_positions_when_serializing_cells', () {
      // AC4 — shaped boards are sparse: absent positions are omitted entirely
      // (no `type: "absent"` filler), and the omitted set matches the mask.
      const numeroCorazon = 2; // Corazón excludes some cells on a 7×7 grid.
      final json = generarNivelJson(numeroCorazon);
      final filas = json['rows'] as int;
      final columnas = json['cols'] as int;
      final celdas = (json['cells'] as List).cast<Map<String, dynamic>>();

      // No filler / no explicit absent markers.
      expect(celdas.any((c) => c['type'] == 'absent'), isFalse,
          reason: 'absent positions must be omitted, not marked');
      // Sparse: fewer cells than the full grid.
      expect(celdas.length, lessThan(filas * columnas),
          reason: 'a Corazón board must exclude some cells');

      // The omitted positions equal exactly the mask's absent set.
      final presentes = celdas
          .map((c) => Posicion.en(fila: c['row'] as int, columna: c['col'] as int))
          .toSet();
      final omitidas = <Posicion>{};
      for (var f = 0; f < filas; f++) {
        for (var col = 0; col < columnas; col++) {
          final pos = Posicion.en(fila: f, columna: col);
          if (!presentes.contains(pos)) omitidas.add(pos);
        }
      }
      final ausentesMascara =
          formaDeNivel(numeroCorazon).ausentes(filas, columnas);
      expect(omitidas, equals(ausentesMascara));

      // And on the reconstructed board those positions are truly absent —
      // void, not a transparent EmptyCell.
      final tablero = construirTablero(json);
      for (final pos in ausentesMascara) {
        expect(tablero.celdaEn(pos), isA<CeldaAusente>(),
            reason: 'omitted position ${pos.fila},${pos.columna} '
                'must load as absent');
      }
    });

    test('should_serialize_full_grid_when_shape_is_square', () {
      // AC4 corollary — Cuadrado (level 1) has no absent cells: fully dense.
      final json = generarNivelJson(1);
      final filas = json['rows'] as int;
      final columnas = json['cols'] as int;
      final celdas = (json['cells'] as List).cast<Map<String, dynamic>>();

      expect(celdas.length, filas * columnas,
          reason: 'a Cuadrado board is fully dense (no absent cells)');
    });
  });
}
