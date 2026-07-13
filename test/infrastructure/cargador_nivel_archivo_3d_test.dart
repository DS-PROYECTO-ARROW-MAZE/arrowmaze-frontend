import 'package:arrowmaze/infrastructure/datasources/cargador_nivel_archivo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 36 (Step 2) — level JSON schema gains `layers` (top-level, default
/// `1`) and `layer` (per cell, default `0`), and `FORWARD`/`BACKWARD` join the
/// direction vocabulary. [CargadorNivelArchivo.derivarAusentes] is pure/static
/// so it is exercised directly here without the Flutter asset bundle.
void main() {
  group('derivarAusentes — layer-aware', () {
    test('should_default_layers_to_one_when_absent', () {
      // Arrange — a dense 2x2 board with no `layers` key at all.
      final json = {
        'rows': 2,
        'cols': 2,
        'cells': [
          {'row': 0, 'col': 0, 'type': 'wall'},
          {'row': 0, 'col': 1, 'type': 'wall'},
          {'row': 1, 'col': 0, 'type': 'wall'},
          {'row': 1, 'col': 1, 'type': 'wall'},
        ],
      };

      // Act
      final ausentes = CargadorNivelArchivo.derivarAusentes(json);

      // Assert — every cell present ⇒ nothing absent (2D behaviour unchanged).
      expect(ausentes, isEmpty);
    });

    test('should_treat_a_position_missing_on_one_layer_as_absent_there_only', () {
      // Arrange — a 1x1x2 board where only layer 0 has a cell.
      final json = {
        'rows': 1,
        'cols': 1,
        'layers': 2,
        'cells': [
          {'row': 0, 'col': 0, 'layer': 0, 'type': 'wall'},
        ],
      };

      // Act
      final ausentes = CargadorNivelArchivo.derivarAusentes(json);

      // Assert — layer 1's (0,0) is absent; layer 0's is not.
      expect(ausentes, [
        {'row': 0, 'col': 0, 'layer': 1, 'type': 'absent'},
      ]);
    });

    test('should_report_nothing_absent_when_every_layer_is_fully_covered', () {
      // Arrange — a 1x2x2 board where every (row,col,layer) triple is present.
      final json = {
        'rows': 1,
        'cols': 2,
        'layers': 2,
        'cells': [
          {'row': 0, 'col': 0, 'layer': 0, 'type': 'arrow', 'id': 1, 'direction': 'FORWARD'},
          {'row': 0, 'col': 1, 'layer': 0, 'type': 'arrow', 'id': 1, 'direction': 'FORWARD'},
          {'row': 0, 'col': 1, 'layer': 1, 'type': 'arrow', 'id': 1, 'direction': 'FORWARD'},
          {'row': 0, 'col': 0, 'layer': 1, 'type': 'empty'},
        ],
      };

      // Act
      final ausentes = CargadorNivelArchivo.derivarAusentes(json);

      // Assert
      expect(ausentes, isEmpty);
    });
  });
}
