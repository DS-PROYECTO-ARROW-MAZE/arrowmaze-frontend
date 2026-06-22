import 'package:arrowmaze/domain/niveles/perfil_dificultad.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 17 — PerfilDificultad complexity profile (AC2).
///
/// Verifies that the profile returns monotonic non-decreasing values for
/// cells and arrows over levels 1…15, matching the backend agreement.
void main() {
  group('PerfilDificultad', () {
    test('should_provide_monotonic_non_decreasing_cells_over_1_to_15', () {
      // Act — collect cells for levels 1…15.
      final cells = List.generate(15, (i) => PerfilDificultad.para(i + 1).totalCeldas);

      // Assert — never decreases as level number goes up.
      for (var i = 1; i < cells.length; i++) {
        expect(
          cells[i],
          greaterThanOrEqualTo(cells[i - 1]),
          reason: 'cells dropped from level ${i + 1} to ${i + 2}',
        );
      }
    });

    test('should_provide_monotonic_non_decreasing_arrows_over_1_to_15', () {
      // Act — collect arrows for levels 1…15.
      final flechas = List.generate(15, (i) => PerfilDificultad.para(i + 1).totalFlechas);

      // Assert — never decreases.
      for (var i = 1; i < flechas.length; i++) {
        expect(
          flechas[i],
          greaterThanOrEqualTo(flechas[i - 1]),
          reason: 'arrows dropped from level ${i + 1} to ${i + 2}',
        );
      }
    });

    test('should_provide_monotonic_non_decreasing_trayectorias_over_1_to_15', () {
      // Act — collect trayectorias for levels 1…15.
      final trayectorias =
          List.generate(15, (i) => PerfilDificultad.para(i + 1).trayectorias);

      // Assert — never decreases.
      for (var i = 1; i < trayectorias.length; i++) {
        expect(
          trayectorias[i],
          greaterThanOrEqualTo(trayectorias[i - 1]),
          reason: 'trayectorias dropped from level ${i + 1} to ${i + 2}',
        );
      }
    });

    test('should_have_level_10_more_complex_than_level_1', () {
      // Arrange
      final nivel1 = PerfilDificultad.para(1);
      final nivel10 = PerfilDificultad.para(10);

      // Assert — level 10 must have at least as many cells and arrows.
      expect(nivel10.totalCeldas, greaterThanOrEqualTo(nivel1.totalCeldas));
      expect(nivel10.totalFlechas, greaterThanOrEqualTo(nivel1.totalFlechas));
      expect(nivel10.trayectorias, greaterThanOrEqualTo(nivel1.trayectorias));
      // And at least one dimension is strictly greater (otherwise same difficulty).
      expect(
        nivel10.totalCeldas > nivel1.totalCeldas ||
            nivel10.totalFlechas > nivel1.totalFlechas ||
            nivel10.trayectorias > nivel1.trayectorias,
        isTrue,
        reason: 'level 10 should be strictly harder than level 1',
      );
    });

    test('should_provide_filas_and_columnas_for_each_level', () {
      for (var nivel = 1; nivel <= 15; nivel++) {
        final perfil = PerfilDificultad.para(nivel);
        expect(perfil.filas, greaterThan(0));
        expect(perfil.columnas, greaterThan(0));
      }
    });
  });
}
