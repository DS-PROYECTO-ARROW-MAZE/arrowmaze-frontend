import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 18 — The timer/untimed/bonus rule is data-driven from `DefinicionNivel`:
///
/// | `numero` | `esBonus` | Timer            | Scoring |
/// |----------|-----------|------------------|---------|
/// | 1–9      | false     | **none**         | yes     |
/// | ≥10      | false     | **countdown**    | yes     |
/// | any      | true      | **none**         | **no**  |
///
/// The rule lives in [DefinicionNivel.esCronometrado] (boundary 9 vs 10) and
/// [DefinicionNivel.esBonus] so no caller branches on `numero`.
void main() {
  group('esCronometrado', () {
    test(
        'should_return_false_when_numero_below_10_and_not_bonus', () {
      const definicion = DefinicionNivel(
        id: 5,
        numero: 5,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
        limiteTiempo: Duration(seconds: 90),
        esBonus: false,
      );

      expect(definicion.esCronometrado, isFalse);
    });

    test('should_return_true_when_numero_10_and_not_bonus', () {
      const definicion = DefinicionNivel(
        id: 10,
        numero: 10,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
        limiteTiempo: Duration(seconds: 90),
        esBonus: false,
      );

      expect(definicion.esCronometrado, isTrue);
    });

    test('should_return_true_when_numero_above_10_and_not_bonus', () {
      const definicion = DefinicionNivel(
        id: 15,
        numero: 15,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
        limiteTiempo: Duration(seconds: 120),
        esBonus: false,
      );

      expect(definicion.esCronometrado, isTrue);
    });

    test('should_return_false_when_bonus_regardless_of_numero', () {
      const definicion = DefinicionNivel(
        id: 20,
        numero: 20,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
        limiteTiempo: Duration(seconds: 90),
        esBonus: true,
      );

      expect(definicion.esCronometrado, isFalse);
    });

    test('should_return_false_at_boundary_9', () {
      const definicion = DefinicionNivel(
        id: 9,
        numero: 9,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
        limiteTiempo: Duration(seconds: 90),
        esBonus: false,
      );

      expect(definicion.esCronometrado, isFalse);
    });

    test('should_return_true_at_boundary_10', () {
      const definicion = DefinicionNivel(
        id: 10,
        numero: 10,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
        limiteTiempo: Duration(seconds: 90),
        esBonus: false,
      );

      expect(definicion.esCronometrado, isTrue);
    });
  });

  group('esBonus', () {
    test('should_default_to_false', () {
      const definicion = DefinicionNivel(
        id: 1,
        numero: 1,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
      );

      expect(definicion.esBonus, isFalse);
    });

    test('should_return_true_when_set', () {
      const definicion = DefinicionNivel(
        id: 20,
        numero: 20,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
        esBonus: true,
      );

      expect(definicion.esBonus, isTrue);
    });
  });

  group('limiteTiempo on bonus', () {
    test('should_return_null_for_bonus_level_even_if_param_provided', () {
      const definicion = DefinicionNivel(
        id: 20,
        numero: 20,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        umbralesEstrellas: [300, 600, 900],
        limiteTiempo: Duration(seconds: 90),
        esBonus: true,
      );

      expect(definicion.limiteTiempo, isNull);
    });
  });
}
