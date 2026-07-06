import 'package:arrowmaze/domain/niveles/repertorio_formas.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 23 — RepertorioFormas shape rotation + MascaraForma (AC3, AC4).
///
/// Verifies the fixed ordered repertoire, deterministic rotation by index,
/// and that the shape mask only populates playable cells.
void main() {
  group('RepertorioFormas', () {
    test(
        'should_rotate_through_shapes_in_fixed_order_when_index_advances',
        () {
      final repertorio = RepertorioFormas();

      expect(repertorio.formaParaIndice(1).nombre, 'Cuadrado');
      expect(repertorio.formaParaIndice(2).nombre, 'Corazón');
      expect(repertorio.formaParaIndice(3).nombre, 'Triángulo');
      expect(repertorio.formaParaIndice(4).nombre, 'Cruz');
      expect(repertorio.formaParaIndice(5).nombre, 'Estrella');
    });

    test('should_wrap_to_first_shape_after_repertoire_length', () {
      final repertorio = RepertorioFormas();

      expect(repertorio.formaParaIndice(6).nombre, 'Cuadrado');
      expect(repertorio.formaParaIndice(7).nombre, 'Corazón');
    });

    test('should_yield_every_shape_over_a_full_cycle', () {
      final repertorio = RepertorioFormas();
      final nombres =
          List.generate(5, (i) => repertorio.formaParaIndice(i + 1).nombre)
              .toSet();

      expect(nombres, containsAll([
        'Cuadrado',
        'Corazón',
        'Triángulo',
        'Cruz',
        'Estrella',
      ]));
    });

    test('should_never_yield_square_only_over_any_5_consecutive_indices', () {
      final repertorio = RepertorioFormas();
      // Check 10 windows of 5 consecutive indices — each window must contain
      // at least one non-square shape.
      for (var start = 1; start <= 10; start++) {
        final nombres =
            List.generate(5, (i) => repertorio.formaParaIndice(start + i).nombre);
        expect(
          nombres.any((n) => n != 'Cuadrado'),
          isTrue,
          reason: 'window starting at $start contains only squares',
        );
      }
    });
  });

  group('MascaraForma', () {
    test('should_generate_absent_positions_for_given_grid', () {
      final mascara =
          RepertorioFormas().formaParaIndice(1); // Cuadrado — no ausentes

      final ausentes = mascara.ausentes(7, 7);

      expect(ausentes, isEmpty);
    });

    test('should_not_populate_playable_cells_outside_mask_for_heart', () {
      // Corazón should exclude at least some cells on a 7×7 grid.
      final mascara =
          RepertorioFormas().formaParaIndice(2); // Corazón

      final ausentes = mascara.ausentes(7, 7);

      expect(ausentes, isNotEmpty,
          reason: 'Corazón should exclude some grid cells');
      // All positions in 7×7 = 49 cells, so at least one should be absent.
      expect(ausentes.length, lessThan(49),
          reason: 'Corazón should have some playable cells too');
    });

    test('should_yield_different_absent_sets_for_different_shapes_on_same_grid',
        () {
      final repertorio = RepertorioFormas();
      final ausentesCuadrado = repertorio.formaParaIndice(1).ausentes(7, 7);
      final ausentesCorazon = repertorio.formaParaIndice(2).ausentes(7, 7);

      expect(ausentesCuadrado, isNot(equals(ausentesCorazon)));
    });
  });
}
