import 'package:arrowmaze/application/ports/fuente_autenticacion.dart';
import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/ports/selector_usuario_progreso.dart';
import 'package:arrowmaze/application/use_cases/activar_progreso_usuario_use_case.dart';
import 'package:arrowmaze/application/use_cases/iniciar_sesion_use_case.dart';
import 'package:arrowmaze/application/use_cases/resultado_inicio_sesion.dart';
import 'package:arrowmaze/domain/progreso/i_cola_sincronizacion.dart';
import 'package:arrowmaze/domain/progreso/run_completado.dart';
import 'package:arrowmaze/domain/sesion/perfil.dart';
import 'package:arrowmaze/domain/sesion/usuario_registrado.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 24 — on login the use case activates the signed-in account's own
/// device-local progression namespace, so their previously unlocked levels are
/// shown (per-user local progress) rather than a wiped/blank slate.
void main() {
  test('should_activate_users_own_progress_when_login_succeeds', () async {
    // Arrange
    final selector = _SelectorFake();
    final cola = _ColaFake();
    final useCase = IniciarSesionUseCase(
      fuenteAutenticacion: _AuthOk(),
      proveedorSesion: _ProveedorSesionFake(),
      activarProgreso: ActivarProgresoUsuarioUseCase(
        selector: selector,
        cola: cola,
      ),
    );

    // Act
    final resultado = await useCase.ejecutar(
      email: 'alice@test.com',
      password: 'pass123',
    );

    // Assert — logged in, and Alice's own progress namespace is now active so
    // the Level Selection renders her real unlocks.
    expect(resultado, isA<InicioSesionExitoso>());
    expect(selector.usuarioActivo, 'alice@test.com');
  });

  test('should_not_activate_progress_when_credentials_invalid', () async {
    // Arrange — auth rejects with invalid credentials.
    final selector = _SelectorFake();
    final useCase = IniciarSesionUseCase(
      fuenteAutenticacion: _AuthInvalido(),
      proveedorSesion: _ProveedorSesionFake(),
      activarProgreso: ActivarProgresoUsuarioUseCase(
        selector: selector,
        cola: _ColaFake(),
      ),
    );

    // Act
    final resultado = await useCase.ejecutar(
      email: 'alice@test.com',
      password: 'wrong',
    );

    // Assert — no session, no namespace switch (nothing to activate).
    expect(resultado, isA<InicioSesionCredencialesInvalidas>());
    expect(selector.usuarioActivo, isNull);
  });
}

class _AuthOk implements FuenteAutenticacion {
  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) async =>
      UsuarioRegistrado(id: 'uuid', email: email, createdAt: DateTime.utc(2026));

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async =>
      'login-token';

  @override
  Future<Perfil> obtenerPerfil() async =>
      const Perfil(id: 'uuid', email: 'alice@test.com');
}

class _AuthInvalido implements FuenteAutenticacion {
  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) async =>
      throw const AutenticacionException('INVALID_CREDENTIALS', 'bad');

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async =>
      throw const AutenticacionException('INVALID_CREDENTIALS', 'bad');

  @override
  Future<Perfil> obtenerPerfil() async =>
      const Perfil(id: 'uuid', email: 'alice@test.com');
}

class _ProveedorSesionFake implements ProveedorSesion {
  String? guardado;

  @override
  Future<String?> obtenerToken() async => guardado;

  @override
  Future<void> guardarToken(String token) async => guardado = token;

  @override
  Future<void> cerrarSesion() async => guardado = null;
}

class _SelectorFake implements SelectorUsuarioProgreso {
  String? usuarioActivo;

  @override
  Future<void> establecerUsuario(String usuario) async =>
      usuarioActivo = usuario;
}

class _ColaFake implements IColaSincronizacion {
  @override
  Future<void> encolar(RunCompletado run) async {}

  @override
  Future<List<RunCompletado>> obtenerPendientes() async => const [];

  @override
  Future<int> cantidadPendientes() async => 0;

  @override
  Future<void> vaciar() async {}
}
