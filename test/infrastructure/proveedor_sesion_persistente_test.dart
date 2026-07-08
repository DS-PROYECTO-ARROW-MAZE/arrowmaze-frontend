import 'package:arrowmaze/infrastructure/sesion/proveedor_sesion_persistente.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue 14 — RED: persistent token storage (AC3 — token management).
///
/// The token must survive across instances (i.e. app restarts), backed by
/// `shared_preferences`. Signing out must remove it.
void main() {
  group('ProveedorSesionPersistente (AC3)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should_return_null_when_no_token_stored', () async {
      // Arrange
      final prefs = await SharedPreferences.getInstance();
      final sesion = ProveedorSesionPersistente(prefs: prefs);

      // Act / Assert
      expect(await sesion.obtenerToken(), isNull);
    });

    test('should_persist_token_when_reloaded_across_instances', () async {
      // Arrange — save with one instance.
      final prefs = await SharedPreferences.getInstance();
      await ProveedorSesionPersistente(prefs: prefs).guardarToken('tok-persist');

      // Act — a brand-new instance reads the same backing store.
      final otra = ProveedorSesionPersistente(prefs: prefs);

      // Assert
      expect(await otra.obtenerToken(), 'tok-persist');
    });

    test('should_clear_token_when_cerrarSesion', () async {
      // Arrange
      final prefs = await SharedPreferences.getInstance();
      final sesion = ProveedorSesionPersistente(prefs: prefs);
      await sesion.guardarToken('tok-bye');

      // Act
      await sesion.cerrarSesion();

      // Assert
      expect(await sesion.obtenerToken(), isNull);
    });
  });
}
