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
  });
}
