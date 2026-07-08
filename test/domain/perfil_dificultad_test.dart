import 'package:arrowmaze/domain/niveles/perfil_dificultad.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 23 — PerfilDificultad aggressive difficulty scaling (AC2).
///
/// Verifies the steep monotonic curve: board size, arrow count, and move
/// budget increase strictly with index, and the minimum floor is 7×7 at
/// every index.
void main() {
  group('PerfilDificultad — aggressive scaling', () {
    test(
        'should_increase_grid_size_and_arrow_count_monotonically_when_index_grows',
        () {
      final profiles =
          List.generate(100, (i) => PerfilDificultad.para(i + 1));

      for (var i = 1; i < profiles.length; i++) {
        expect(
          profiles[i].filas,
          greaterThanOrEqualTo(profiles[i - 1].filas),
          reason: 'filas dropped from index ${i + 1} to ${i + 2}',
        );
        expect(
          profiles[i].columnas,
          greaterThanOrEqualTo(profiles[i - 1].columnas),
          reason: 'columnas dropped from index ${i + 1} to ${i + 2}',
        );
        expect(
          profiles[i].totalFlechas,
          greaterThanOrEqualTo(profiles[i - 1].totalFlechas),
          reason: 'totalFlechas dropped from index ${i + 1} to ${i + 2}',
        );
        expect(
          profiles[i].trayectorias,
          greaterThanOrEqualTo(profiles[i - 1].trayectorias),
          reason: 'trayectorias dropped from index ${i + 1} to ${i + 2}',
        );
      }
    });

    test('should_never_yield_board_smaller_than_7x7_when_index_varies', () {
      for (var i = 1; i <= 50; i++) {
        final p = PerfilDificultad.para(i);
        expect(p.filas, greaterThanOrEqualTo(7),
            reason: 'filas < 7 at index $i');
        expect(p.columnas, greaterThanOrEqualTo(7),
            reason: 'columnas < 7 at index $i');
      }
    });

    test('should_increase_move_budget_monotonically_when_index_grows', () {
      final profiles =
          List.generate(100, (i) => PerfilDificultad.para(i + 1));

      expect(profiles[0].presupuestoMovimientos, greaterThan(0));

      for (var i = 1; i < profiles.length; i++) {
        expect(
          profiles[i].presupuestoMovimientos,
          greaterThanOrEqualTo(profiles[i - 1].presupuestoMovimientos),
          reason:
              'presupuestoMovimientos dropped from index ${i + 1} to ${i + 2}: '
              '${profiles[i - 1].presupuestoMovimientos} → ${profiles[i].presupuestoMovimientos}',
        );
      }
    });

    test('should_yield_large_dense_board_when_index_is_late', () {
      final p = PerfilDificultad.para(100);

      expect(p.filas, greaterThanOrEqualTo(15),
          reason: 'late index 100 should be at least 15×15');
      expect(p.columnas, greaterThanOrEqualTo(15),
          reason: 'late index 100 should be at least 15×15');
      expect(p.totalFlechas, greaterThanOrEqualTo(100),
          reason: 'late index 100 should have at least 100 arrow segments');
      expect(p.trayectorias, greaterThan(5),
          reason: 'late index 100 should have >5 arrow paths');
    });
  });
}
