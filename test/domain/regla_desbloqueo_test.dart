import 'package:arrowmaze/domain/niveles/regla_desbloqueo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 13 — the sequential unlock policy (DM §10.3).
void main() {
  group('ReglaDesbloqueoSecuencial', () {
    const regla = ReglaDesbloqueoSecuencial();

    test('should_unlock_first_level_when_nothing_completed', () {
      // Arrange / Act
      final desbloqueado = regla.estaDesbloqueado(1, <int>{});

      // Assert — level 1 is always open.
      expect(desbloqueado, isTrue);
    });

    test('should_lock_second_level_when_first_not_completed', () {
      // Arrange / Act
      final desbloqueado = regla.estaDesbloqueado(2, <int>{});

      // Assert
      expect(desbloqueado, isFalse);
    });

    test('should_unlock_level_when_previous_completed', () {
      // Arrange — level 2 is done.
      final completados = {1, 2};

      // Act
      final desbloqueado = regla.estaDesbloqueado(3, completados);

      // Assert
      expect(desbloqueado, isTrue);
    });

    test('should_keep_level_locked_when_only_earlier_non_adjacent_completed',
        () {
      // Arrange — completing level 1 must not unlock level 3 (needs 2).
      final completados = {1};

      // Act
      final desbloqueado = regla.estaDesbloqueado(3, completados);

      // Assert
      expect(desbloqueado, isFalse);
    });

    // Ticket 32 (AC2) — monotonic-unlock invariant: over a prefix-complete set
    // {1..k} (the shape sequential play produces), an unlocked level always
    // implies every earlier level is unlocked. This documents the rule contract
    // that the restore path must preserve (no holes reach the rule).
    test('should_keep_unlock_monotonic_over_a_prefix_completed_set', () {
      // Arrange — levels 1‑5 completed; check the gate up to level 8.
      final completados = {1, 2, 3, 4, 5};

      // Act
      final estados = [
        for (var id = 1; id <= 8; id++) regla.estaDesbloqueado(id, completados),
      ];

      // Assert — a run of unlocked levels followed only by locked ones.
      var vistoBloqueado = false;
      for (final desbloqueado in estados) {
        if (!desbloqueado) {
          vistoBloqueado = true;
        } else {
          expect(vistoBloqueado, isFalse,
              reason: 'An unlocked level followed a locked one — not monotonic.');
        }
      }
      // Concretely: 1‑6 unlocked (5 completed → 6 open), 7‑8 locked.
      expect(estados, [true, true, true, true, true, true, false, false]);
    });
  });
}
