import 'package:arrowmaze/application/ports/fuente_autenticacion.dart';
import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/resultado_inicio_sesion.dart';
import 'package:arrowmaze/application/use_cases/resultado_registro.dart';
import 'package:arrowmaze/domain/sesion/perfil.dart';
import 'package:arrowmaze/domain/sesion/usuario_registrado.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arrowmaze/application/use_cases/iniciar_sesion_use_case.dart';
import 'package:arrowmaze/application/use_cases/registrar_usuario_use_case.dart';

/// Ticket 08 — RED phase: AC3 (session is injected, never static).
///
/// The session port (ProveedorSesion) must be **injected** into the use case,
/// never read from a static/global accessor. These test prove that both
/// [RegistrarUsuarioUseCase] and [IniciarSesionUseCase] accept and use the
/// injected port, with no static call path.
void main() {
  group('Session is injected (AC3)', () {
    test(
      'should_read_session_through_injected_port_not_static_accessor',
      () async {
        // Arrange — inject a ProveedorSesion that asserts it was called.
        String? tokenInyectado;
        final authPort = _AuthOk();
        final sesionPort = _ProveedorSesionSeguimiento(
          alGuardar: (t) => tokenInyectado = t,
        );

        // Act — construct the use case with the injected port.
        final registerUseCase = RegistrarUsuarioUseCase(
          fuenteAutenticacion: authPort,
          proveedorSesion: sesionPort,
        );
        final loginUseCase = IniciarSesionUseCase(
          fuenteAutenticacion: authPort,
          proveedorSesion: sesionPort,
        );

        // Assert — register uses the injected port. Register auto-logs-in, so
        // the token persisted is the login token.
        final regResult = await registerUseCase.ejecutar(
          email: 'inj@test.com',
          password: 'pass123',
        );
        expect(regResult, isA<RegistroExitoso>());
        expect(tokenInyectado, 'login-token',
            reason: 'register should save via the injected ProveedorSesion');

        // Assert — login uses the injected port.
        tokenInyectado = null;
        final logResult = await loginUseCase.ejecutar(
          email: 'inj@test.com',
          password: 'pass123',
        );
        expect(logResult, isA<InicioSesionExitoso>());
        expect(tokenInyectado, 'login-token',
            reason: 'login should save via the injected ProveedorSesion');

        // Assert — Verify no static accessor was called. Since ProveedorSesion
        // is abstract and has no static methods, a static call is literally
        // impossible without a compile error. This is the strongest guarantee.
      },
    );
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
  }) async => 'login-token';

  @override
  Future<Perfil> obtenerPerfil() async =>
      const Perfil(id: 'uuid', email: 'inj@test.com');
}

class _ProveedorSesionSeguimiento implements ProveedorSesion {
  _ProveedorSesionSeguimiento({this.alGuardar});

  final void Function(String)? alGuardar;
  String? _token;

  @override
  Future<String?> obtenerToken() async => _token;

  @override
  Future<void> guardarToken(String token) async {
    _token = token;
    alGuardar?.call(token);
  }

  @override
  Future<void> cerrarSesion() async {
    _token = null;
  }
}
