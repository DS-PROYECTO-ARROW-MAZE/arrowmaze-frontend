import 'package:arrowmaze/infrastructure/progreso/progreso_local_persistente.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ticket 13 — the shared_preferences-backed progression store (DM §10.1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgresoLocalPersistente', () {
    setUp(() {
      // Each test starts with empty, mocked persistent storage.
      SharedPreferences.setMockInitialValues({});
    });

    test('should_report_no_completed_levels_when_storage_empty', () async {
      // Arrange
      final store = ProgresoLocalPersistente();

      // Act
      final completados = await store.nivelesCompletados();

      // Assert
      expect(completados, isEmpty);
      expect(await store.mejorEstrellas(1), 0);
    });

    test('should_persist_completion_and_stars_when_registered', () async {
      // Arrange
      final store = ProgresoLocalPersistente();

      // Act
      await store.registrarCompletado(idNivel: 1, estrellas: 2);

      // Assert
      expect(await store.nivelesCompletados(), {1});
      expect(await store.mejorEstrellas(1), 2);
    });

    test('should_keep_best_stars_when_replayed_with_lower_score', () async {
      // Arrange — first a 3-star clear.
      final store = ProgresoLocalPersistente();
      await store.registrarCompletado(idNivel: 1, estrellas: 3);

      // Act — a worse replay must not lower the record.
      await store.registrarCompletado(idNivel: 1, estrellas: 1);

      // Assert
      expect(await store.mejorEstrellas(1), 3);
    });

    test('should_mark_completed_when_cleared_with_zero_stars', () async {
      // Arrange
      final store = ProgresoLocalPersistente();

      // Act
      await store.registrarCompletado(idNivel: 4, estrellas: 0);

      // Assert — a 0-star clear still counts as completed (unlocks the next).
      expect(await store.nivelesCompletados(), {4});
      expect(await store.mejorEstrellas(4), 0);
    });

    test('should_wipe_all_progress_when_limpiar_called', () async {
      // Arrange — several levels recorded.
      final store = ProgresoLocalPersistente();
      await store.registrarCompletado(idNivel: 1, estrellas: 3);
      await store.registrarCompletado(idNivel: 2, estrellas: 1);
      await store.registrarCompletado(idNivel: 3, estrellas: 0);
      expect(await store.nivelesCompletados(), {1, 2, 3});

      // Act — wipe (logout / account switch).
      await store.limpiar();

      // Assert — no progression remains; a brand-new account starts fresh.
      expect(await store.nivelesCompletados(), isEmpty);
      expect(await store.mejorEstrellas(1), 0);
    });

    test('should_leave_unrelated_keys_intact_when_limpiar_called', () async {
      // Arrange — a non-progress key (e.g. the session token) coexists in prefs.
      SharedPreferences.setMockInitialValues({
        'arrowmaze.sesion.token': 'tok-keep',
      });
      final store = ProgresoLocalPersistente();
      await store.registrarCompletado(idNivel: 5, estrellas: 2);

      // Act
      await store.limpiar();

      // Assert — progress gone, but the unrelated key is untouched.
      expect(await store.nivelesCompletados(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('arrowmaze.sesion.token'), 'tok-keep');
    });

    test('should_survive_a_new_instance_when_backed_by_same_storage', () async {
      // Arrange — write through one instance.
      await ProgresoLocalPersistente().registrarCompletado(
        idNivel: 2,
        estrellas: 1,
      );

      // Act — a fresh instance reads the same mocked store (restart analogue).
      final otra = ProgresoLocalPersistente();

      // Assert
      expect(await otra.nivelesCompletados(), {2});
      expect(await otra.mejorEstrellas(2), 1);
    });
  });
}
