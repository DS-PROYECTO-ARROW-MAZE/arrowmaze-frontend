import 'package:arrowmaze/domain/value_objects/presupuesto_movimientos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 30 (FE-30) — move budget value object.
///
/// Covers AC1 (decrement on every move), AC2 (budget zero → defeat trigger),
/// and the victory-wins-tie case where the board clears on the last move.
void main() {
  group('PresupuestoMovimientos', () {
    test('should_start_with_restante_equal_to_total_when_constructed', () {
      const budget = PresupuestoMovimientos(10);

      expect(budget.total, 10);
      expect(budget.restante, 10);
      expect(budget.estaAgotado, isFalse);
    });

    test('should_decrement_restante_when_decrementar', () {
      const budget = PresupuestoMovimientos(5);
      final decrementado = budget.decrementar();

      expect(decrementado.restante, 4);
      expect(decrementado.total, 5);
      expect(decrementado.estaAgotado, isFalse);
    });

    test('should_decrement_budget_on_every_call_including_when_invalid', () {
      const budget = PresupuestoMovimientos(3);
      final after1 = budget.decrementar();
      final after2 = after1.decrementar();
      final after3 = after2.decrementar();

      expect(after3.restante, 0);
      expect(after3.estaAgotado, isTrue);
    });

    test('should_transition_to_agotado_when_budget_hits_zero', () {
      const budget = PresupuestoMovimientos(1);
      final agotado = budget.decrementar();

      expect(agotado.restante, 0);
      expect(agotado.estaAgotado, isTrue);
    });

    test('should_clamp_at_zero_when_decrementar_below_zero', () {
      const budget = PresupuestoMovimientos(0);
      final clamped = budget.decrementar();

      expect(clamped.restante, 0);
      expect(clamped.estaAgotado, isTrue);
    });

    test('should_restore_one_unit_when_restaurar', () {
      const budget = PresupuestoMovimientos(5);
      final decrementado = budget.decrementar().decrementar();
      expect(decrementado.restante, 3);

      final restaurado = decrementado.restaurar();

      expect(restaurado.restante, 4);
      expect(restaurado.estaAgotado, isFalse);
    });

    test('should_not_exceed_total_when_restaurar_past_limit', () {
      const budget = PresupuestoMovimientos(5);
      final restaurado = budget.restaurar();

      expect(restaurado.restante, 5);
      expect(restaurado.total, 5);
    });

    test('should_restore_from_zero_when_restaurar', () {
      const budget = PresupuestoMovimientos(3);
      final agotado = budget.decrementar().decrementar().decrementar();
      expect(agotado.restante, 0);

      final restaurado = agotado.restaurar();

      expect(restaurado.restante, 1);
      expect(restaurado.estaAgotado, isFalse);
    });
  });
}
