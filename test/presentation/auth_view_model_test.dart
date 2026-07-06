import 'package:arrowmaze/application/ports/fuente_autenticacion.dart';
import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/cerrar_sesion_use_case.dart';
import 'package:arrowmaze/application/use_cases/obtener_perfil_use_case.dart';
import 'package:arrowmaze/domain/sesion/perfil.dart';
import 'package:arrowmaze/domain/sesion/usuario_registrado.dart';
import 'package:arrowmaze/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 20 — AuthViewModel logout behavior.
void main() {
  group('AuthViewModel — startup session validation', () {
    test('should_authenticate_when_stored_token_is_valid', () async {
      // Arrange — a stored token that the backend confirms via GET /auth/me.
      final sesion = _ProveedorSesionFake();
      await sesion.guardarToken('tok-valido');
      final viewModel = AuthViewModel(
        proveedorSesion: sesion,
        cerrarSesion: CerrarSesionUseCase(proveedorSesion: sesion),
        verificarPerfil:
            ObtenerPerfilUseCase(fuenteAutenticacion: _AuthPerfilOk()),
      );

      // Act — let the async _verificarSesion complete.
      await Future(() {});
      await Future(() {});

      // Assert — token confirmed ⇒ auto-forward to Level Select.
      expect(viewModel.estado.autenticado, isTrue);
      expect(await sesion.obtenerToken(), 'tok-valido');
    });

    test('should_clear_token_and_stay_on_login_when_stored_token_is_invalid',
        () async {
      // Arrange — a stale token that GET /auth/me rejects (401).
      final sesion = _ProveedorSesionFake();
      await sesion.guardarToken('tok-expirado');
      final viewModel = AuthViewModel(
        proveedorSesion: sesion,
        cerrarSesion: CerrarSesionUseCase(proveedorSesion: sesion),
        verificarPerfil:
            ObtenerPerfilUseCase(fuenteAutenticacion: _AuthPerfilRechaza()),
      );

      // Act
      await Future(() {});
      await Future(() {});

      // Assert — not authenticated (login screen stays) and dead token dropped.
      expect(viewModel.estado.autenticado, isFalse);
      expect(await sesion.obtenerToken(), isNull);
    });
  });

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

/// Auth source whose `GET /auth/me` succeeds — models a still-valid token.
class _AuthPerfilOk implements FuenteAutenticacion {
  @override
  Future<Perfil> obtenerPerfil() async =>
      const Perfil(id: 'u1', email: 'a@b.com');

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();

  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();
}

/// Auth source whose `GET /auth/me` throws — models an expired/invalid token.
class _AuthPerfilRechaza implements FuenteAutenticacion {
  @override
  Future<Perfil> obtenerPerfil() async =>
      throw const AutenticacionException('UNAUTHORIZED', 'token expired');

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();

  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();
}
