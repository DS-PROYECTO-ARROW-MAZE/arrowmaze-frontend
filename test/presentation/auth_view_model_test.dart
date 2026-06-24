import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/cerrar_sesion_use_case.dart';
import 'package:arrowmaze/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 20 — AuthViewModel logout behavior.
void main() {
  group('AuthViewModel (Issue 20 — logout)', () {
    test('should_expose_sesion_cerrada_when_logout', () async {
      // Arrange — signed-in session.
      final sesion = _ProveedorSesionFake();
      await sesion.guardarToken('tok-abc');
      final viewModel = AuthViewModel(
        proveedorSesion: sesion,
        cerrarSesion: CerrarSesionUseCase(proveedorSesion: sesion),
      );

      // Stop the built-in _verificarSesion from triggering navigation listeners
      // during arrange; clear any notifications from token detection.
      await Future(() {});
      expect(viewModel.estado.autenticado, isTrue);

      // Act
      await viewModel.cerrarSesion();

      // Assert — state reflects post-logout.
      expect(viewModel.estado.sesionCerrada, isTrue);
      expect(viewModel.estado.autenticado, isFalse);
      expect(viewModel.estado.email, '');
      expect(viewModel.estado.password, '');
    });

    test('should_reset_form_fields_when_logout', () async {
      // Arrange — user filled form fields but is authenticated.
      final sesion = _ProveedorSesionFake();
      await sesion.guardarToken('tok-abc');
      final viewModel = AuthViewModel(
        proveedorSesion: sesion,
        cerrarSesion: CerrarSesionUseCase(proveedorSesion: sesion),
      );
      viewModel.cambiarEmail('a@b.com');
      viewModel.cambiarPassword('secret');
      await Future(() {});

      // Act
      await viewModel.cerrarSesion();

      // Assert — all fields cleared.
      expect(viewModel.estado.email, '');
      expect(viewModel.estado.password, '');
      expect(viewModel.estado.mensajeError, isNull);
    });
  });
}

/// A fake [ProveedorSesion] for ViewModel tests.
class _ProveedorSesionFake implements ProveedorSesion {
  String? _token;

  @override
  Future<String?> obtenerToken() async => _token;

  @override
  Future<void> guardarToken(String token) async {
    _token = token;
  }

  @override
  Future<void> cerrarSesion() async {
    _token = null;
  }
}
