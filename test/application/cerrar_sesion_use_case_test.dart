import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/cerrar_sesion_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 20 — CerrarSesionUseCase delegates to ProveedorSesion.cerrarSesion().
void main() {
  group('CerrarSesionUseCase (Issue 20)', () {
    test('should_clear_session_when_logout', () async {
      // Arrange — a fake session that starts with a stored token.
      final sesion = _ProveedorSesionFake();
      sesion.guardado = 'tok-abc';
      final useCase = CerrarSesionUseCase(proveedorSesion: sesion);

      // Act
      await useCase.ejecutar();

      // Assert — token is cleared.
      final token = await sesion.obtenerToken();
      expect(token, isNull);
    });

    test('should_remain_cleared_when_already_logged_out', () async {
      // Arrange — no token exists.
      final sesion = _ProveedorSesionFake();
      final useCase = CerrarSesionUseCase(proveedorSesion: sesion);

      // Act
      await useCase.ejecutar();

      // Assert — no error thrown; still null.
      final token = await sesion.obtenerToken();
      expect(token, isNull);
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
