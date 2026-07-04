import 'package:arrowmaze/infrastructure/preferencias/preferencias_usuario_persistente.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ticket 27 — persistence round-trip for sound + language prefs (AC2/AC3/AC4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferenciasUsuarioPersistente', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── AC2 + AC3 + AC4 ──────────────────────────────────────────────────────
    test('should_round_trip_sound_and_language_across_instances', () async {
      // Arrange — write through one instance
      final store1 = PreferenciasUsuarioPersistente();
      await store1.guardarSonidoHabilitado(false);
      await store1.guardarIdioma('es');

      // Act — a brand-new instance (simulates app restart)
      final store2 = PreferenciasUsuarioPersistente();

      // Assert — both values survived the restart
      expect(await store2.leerSonidoHabilitado(), isFalse);
      expect(await store2.leerIdioma(), 'es');
    });

    // ── AC5 (defaults on first run) ───────────────────────────────────────────
    test('should_return_defaults_on_first_run', () async {
      // Arrange
      final store = PreferenciasUsuarioPersistente();

      // Assert — first run: sound defaults to true, idioma is null (caller
      // decides the fallback based on device locale, AC5)
      expect(await store.leerSonidoHabilitado(), isTrue);
      expect(await store.leerIdioma(), isNull);
    });

    test('should_persist_sound_and_language_independently', () async {
      // Arrange
      final store = PreferenciasUsuarioPersistente();
      await store.guardarSonidoHabilitado(false);
      await store.guardarIdioma('en');

      // Act — change only the language
      await store.guardarIdioma('es');

      // Assert — sound is unchanged, language updated
      expect(await store.leerSonidoHabilitado(), isFalse);
      expect(await store.leerIdioma(), 'es');
    });

    test('should_overwrite_sound_when_saved_again', () async {
      // Arrange
      final store = PreferenciasUsuarioPersistente();
      await store.guardarSonidoHabilitado(false);

      // Act
      await store.guardarSonidoHabilitado(true);

      // Assert
      expect(await store.leerSonidoHabilitado(), isTrue);
    });

    test('should_leave_other_prefs_keys_intact', () async {
      // Arrange — an unrelated key exists
      SharedPreferences.setMockInitialValues({
        'arrowmaze.sesion.token': 'tok-xyz',
      });
      final store = PreferenciasUsuarioPersistente();

      // Act
      await store.guardarSonidoHabilitado(false);
      await store.guardarIdioma('es');

      // Assert — unrelated key is untouched
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('arrowmaze.sesion.token'), 'tok-xyz');
    });
  });
}
