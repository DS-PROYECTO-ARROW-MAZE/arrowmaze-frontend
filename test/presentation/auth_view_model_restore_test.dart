import 'package:arrowmaze/application/ports/fuente_autenticacion.dart';
import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/cerrar_sesion_use_case.dart';
import 'package:arrowmaze/application/use_cases/iniciar_sesion_use_case.dart';
import 'package:arrowmaze/application/use_cases/restaurar_progreso_use_case.dart';
import 'package:arrowmaze/domain/sesion/perfil.dart';
import 'package:arrowmaze/domain/sesion/usuario_registrado.dart';
import 'package:arrowmaze/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 24 AC2 — AuthViewModel must invoke RestaurarProgresoUseCase after a
/// successful login so the Level Select renders the player's server-side
/// unlocked levels.
void main() {
  group('AuthViewModel — restore on login (Ticket 24 AC2)', () {
    test('should_invoke_restore_after_successful_login_before_navigation',
        () async {
      // Arrange — a fake auth source that returns a token.
      final sesion = _ProveedorSesionFake();
      final auth = _FuenteAutenticacionFake();
      final restore = _RestaurarProgresoSpy();
      final loginUseCase = IniciarSesionUseCase(
        fuenteAutenticacion: auth,
        proveedorSesion: sesion,
      );
      final viewModel = AuthViewModel(
        proveedorSesion: sesion,
        cerrarSesion: CerrarSesionUseCase(proveedorSesion: sesion),
        iniciarSesion: loginUseCase,
        restaurarProgreso: restore,
      );

      viewModel.cambiarEmail('a@b.com');
      viewModel.cambiarPassword('secret');
      await Future(() {});

      expect(viewModel.estado.autenticado, isFalse);

      // Act — submit login form.
      await viewModel.enviar();

      // Assert — authenticated + restore was called.
      expect(viewModel.estado.autenticado, isTrue);
      expect(viewModel.estado.cargando, isFalse);
      expect(restore.fueLlamado, isTrue);
    });

    test(
        'should_not_block_navigation_when_restore_fails_graceful_degradation',
        () async {
      // Arrange — restore always throws, simulating offline/401.
      final sesion = _ProveedorSesionFake();
      final auth = _FuenteAutenticacionFake();
      final restore = _RestaurarProgresoQueFalla();
      final loginUseCase = IniciarSesionUseCase(
        fuenteAutenticacion: auth,
        proveedorSesion: sesion,
      );
      final viewModel = AuthViewModel(
        proveedorSesion: sesion,
        cerrarSesion: CerrarSesionUseCase(proveedorSesion: sesion),
        iniciarSesion: loginUseCase,
        restaurarProgreso: restore,
      );

      viewModel.cambiarEmail('a@b.com');
      viewModel.cambiarPassword('secret');
      await Future(() {});

      // Act
      await viewModel.enviar();

      // Assert — still authenticated; restore failure is swallowed.
      expect(viewModel.estado.autenticado, isTrue);
      expect(viewModel.estado.cargando, isFalse);
      expect(viewModel.estado.mensajeError, isNull);
    });

    test('should_not_restore_when_login_fails', () async {
      // Arrange — invalid credentials.
      final sesion = _ProveedorSesionFake();
      final auth = _FuenteAutenticacionQueFalla();
      final restore = _RestaurarProgresoSpy();
      final loginUseCase = IniciarSesionUseCase(
        fuenteAutenticacion: auth,
        proveedorSesion: sesion,
      );
      final viewModel = AuthViewModel(
        proveedorSesion: sesion,
        cerrarSesion: CerrarSesionUseCase(proveedorSesion: sesion),
        iniciarSesion: loginUseCase,
        restaurarProgreso: restore,
      );

      viewModel.cambiarEmail('wrong@b.com');
      viewModel.cambiarPassword('bad');
      await Future(() {});

      // Act
      await viewModel.enviar();

      // Assert — not authenticated, restore was never called.
      expect(viewModel.estado.autenticado, isFalse);
      expect(restore.fueLlamado, isFalse);
      expect(viewModel.estado.mensajeError, isNotNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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

class _FuenteAutenticacionFake implements FuenteAutenticacion {
  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async =>
      'tok-fake';

  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError('register not used in tests');

  @override
  Future<Perfil> obtenerPerfil() async =>
      throw UnimplementedError('perfil not used in tests');
}

class _FuenteAutenticacionQueFalla implements FuenteAutenticacion {
  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async {
    throw AutenticacionException('INVALID_CREDENTIALS', 'wrong');
  }

  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError('register not used in tests');

  @override
  Future<Perfil> obtenerPerfil() async =>
      throw UnimplementedError('perfil not used in tests');
}

class AutenticacionException implements Exception {
  AutenticacionException(this.codigo, this.mensaje);

  final String codigo;
  final String mensaje;
}

class _RestaurarProgresoSpy implements RestaurarProgresoUseCase {
  bool fueLlamado = false;

  @override
  Future<void> ejecutar() async {
    fueLlamado = true;
  }
}

class _RestaurarProgresoQueFalla implements RestaurarProgresoUseCase {
  @override
  Future<void> ejecutar() async => throw Exception('Network error');
}