import 'package:arrowmaze/application/ports/fuente_autenticacion.dart';
import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/resultado_registro.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arrowmaze/application/use_cases/registrar_usuario_use_case.dart';

/// Ticket 08 — RED phase: ProveedorSesion + FuenteAutenticacion + RegistrarUsuarioUseCase.
///
/// These tests drive the use case with **fake** ports so they never touch
/// HTTP, shared preferences, or any infrastructure.
void main() {
  group('RegistrarUsuarioUseCase (AC1, AC2)', () {
    test(
      'should_store_token_via_ProveedorSesion_when_register_succeeds',
      () async {
        // Arrange — a fake auth source that returns a token, a fake session
        // storage that records what was saved.
        String? tokenGuardado;
        final authPort = _FuenteAutenticacionFake(exito: true, token: 'tok-abc');
        final sesionPort = _ProveedorSesionFake(
          alGuardar: (t) => tokenGuardado = t,
        );
        final useCase = RegistrarUsuarioUseCase(
          fuenteAutenticacion: authPort,
          proveedorSesion: sesionPort,
        );

        // Act
        final resultado = await useCase.ejecutar(
          email: 'a@b.com',
          password: '123456',
          username: 'Alice',
        );

        // Assert — the token was persisted via the injected port.
        expect(resultado, isA<RegistroExitoso>());
        expect(tokenGuardado, 'tok-abc');
      },
    );

    test(
      'should_surface_mapped_error_when_email_duplicate',
      () async {
        // Arrange — a fake auth source that rejects with duplicate-email code.
        final authPort = _FuenteAutenticacionFake(
          exito: false,
          errorCodigo: 'EMAIL_DUPLICATE',
          errorMensaje: 'Email already registered',
        );
        final sesionPort = _ProveedorSesionFake();
        final useCase = RegistrarUsuarioUseCase(
          fuenteAutenticacion: authPort,
          proveedorSesion: sesionPort,
        );

        // Act
        final resultado = await useCase.ejecutar(
          email: 'dupe@b.com',
          password: '123456',
          username: 'Dupe',
        );

        // Assert — the domain error is mapped to the clean ViewState type,
        // not thrown as an unhandled exception.
        expect(resultado, isA<RegistroEmailDuplicado>());
      },
    );
  });
}

/// A fake [FuenteAutenticacion] for use-case tests.
class _FuenteAutenticacionFake implements FuenteAutenticacion {
  _FuenteAutenticacionFake({
    required this.exito,
    this.token,
    this.errorCodigo,
    this.errorMensaje,
  });

  final bool exito;
  final String? token;
  final String? errorCodigo;
  final String? errorMensaje;

  @override
  Future<String> registrar({
    required String email,
    required String password,
    required String username,
  }) {
    if (exito) {
      return Future.value(token!);
    }
    return Future.error(
      AutenticacionException(
        errorCodigo!,
        errorMensaje!,
      ),
    );
  }

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) {
    return Future.value(token ?? 'tok-default');
  }
}

/// A fake [ProveedorSesion] for use-case tests.
class _ProveedorSesionFake implements ProveedorSesion {
  _ProveedorSesionFake({this.alGuardar});

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
