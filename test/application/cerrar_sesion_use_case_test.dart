import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/cerrar_sesion_use_case.dart';
import 'package:arrowmaze/infrastructure/progreso/progreso_local_persistente.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue 20 / Ticket 24 — CerrarSesionUseCase clears the session token and
/// **retains** device-local progression (progress is per-user, so it reappears
/// on the next login rather than being wiped).
void main() {
  group('CerrarSesionUseCase', () {
    test('should_clear_session_when_logout', () async {
      // Arrange — a fake session that starts with a stored token.
      final sesion = _ProveedorSesionFake();
      sesion.guardado = 'tok-abc';
      final useCase = CerrarSesionUseCase(proveedorSesion: sesion);

      // Act
      await useCase.ejecutar();

      // Assert — token is cleared.
      expect(await sesion.obtenerToken(), isNull);
    });

    test('should_retain_local_progress_when_logout', () async {
      // Arrange — a signed-in user with device-local progress on their namespace.
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final progreso = ProgresoLocalPersistente();
      await progreso.establecerUsuario('alice@test.com');
      await progreso.registrarCompletado(idNivel: 1, estrellas: 3);
      await progreso.registrarCompletado(idNivel: 2, estrellas: 1);

      final sesion = _ProveedorSesionFake()..guardado = 'tok-abc';
      final useCase = CerrarSesionUseCase(proveedorSesion: sesion);

      // Act
      await useCase.ejecutar();

      // Assert — token cleared, but the user's progress survives so a re-login
      // shows their previously unlocked levels (Ticket 24).
      expect(await sesion.obtenerToken(), isNull);
      expect(await progreso.nivelesCompletados(), {1, 2});
      expect(await progreso.mejorEstrellas(1), 3);
    });

    test('should_remain_cleared_when_already_logged_out', () async {
      // Arrange — no token exists.
      final sesion = _ProveedorSesionFake();
      final useCase = CerrarSesionUseCase(proveedorSesion: sesion);

      // Act
      await useCase.ejecutar();

      // Assert — no error thrown; still null.
      expect(await sesion.obtenerToken(), isNull);
    });
  });
}

/// A fake [ProveedorSesion] for use-case tests.
class _ProveedorSesionFake implements ProveedorSesion {
  String? guardado;

  @override
  Future<String?> obtenerToken() async => guardado;

  @override
  Future<void> guardarToken(String token) async {
    guardado = token;
  }

  @override
  Future<void> cerrarSesion() async {
    guardado = null;
  }
}
