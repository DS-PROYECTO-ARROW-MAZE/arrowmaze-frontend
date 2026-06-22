import 'package:arrowmaze/application/ports/consulta_progreso_local.dart';
import 'package:arrowmaze/application/ports/fuente_autenticacion.dart';
import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/limpiar_progreso_local_use_case.dart';
import 'package:arrowmaze/application/use_cases/resultado_registro.dart';
import 'package:arrowmaze/domain/progreso/i_cola_sincronizacion.dart';
import 'package:arrowmaze/domain/progreso/run_completado.dart';
import 'package:arrowmaze/domain/sesion/perfil.dart';
import 'package:arrowmaze/domain/sesion/usuario_registrado.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arrowmaze/application/use_cases/registrar_usuario_use_case.dart';

/// Issue 14 — RED: RegistrarUsuarioUseCase against the real backend contract.
///
/// `/auth/register` returns the created user (no token), so the use case
/// registers and then logs in to obtain and persist the session token. Ports
/// are faked so tests never touch HTTP or shared preferences.
void main() {
  group('RegistrarUsuarioUseCase (Issue 14)', () {
    test(
      'should_register_then_login_and_store_token_when_register_succeeds',
      () async {
        // Arrange — register returns a user; login yields a token to persist.
        String? tokenGuardado;
        final authPort = _FuenteAutenticacionFake(
          usuario: UsuarioRegistrado(
            id: 'uuid-1',
            email: 'a@b.com',
            createdAt: DateTime.utc(2026, 6, 21),
          ),
          token: 'tok-abc',
        );
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
        );

        // Assert — registered, logged in, and the login token was persisted.
        expect(resultado, isA<RegistroExitoso>());
        expect(authPort.registroLlamado, isTrue);
        expect(tokenGuardado, 'tok-abc');
      },
    );

    test(
      'should_wipe_local_progress_when_register_succeeds',
      () async {
        // Arrange — a new account must start with no inherited unlocks.
        final authPort = _FuenteAutenticacionFake(
          usuario: UsuarioRegistrado(
            id: 'uuid-2',
            email: 'fresh@b.com',
            createdAt: DateTime.utc(2026, 6, 22),
          ),
          token: 'tok-fresh',
        );
        final progreso = _ProgresoLocalFake()..completados = {1, 2, 3};
        final useCase = RegistrarUsuarioUseCase(
          fuenteAutenticacion: authPort,
          proveedorSesion: _ProveedorSesionFake(),
          limpiarProgresoLocal: LimpiarProgresoLocalUseCase(
            progreso: progreso,
            cola: _ColaFake(),
          ),
        );

        // Act
        final resultado = await useCase.ejecutar(
          email: 'fresh@b.com',
          password: '123456',
        );

        // Assert — registered and any prior device-local progress wiped.
        expect(resultado, isA<RegistroExitoso>());
        expect(progreso.limpiado, isTrue);
        expect(progreso.completados, isEmpty);
      },
    );

    test(
      'should_surface_mapped_error_when_email_duplicate',
      () async {
        // Arrange — register rejects with the duplicate-email code.
        final authPort = _FuenteAutenticacionFake(
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
        );

        // Assert — mapped to a clean result; no token stored.
        expect(resultado, isA<RegistroEmailDuplicado>());
        expect(sesionPort.guardado, isNull);
      },
    );
  });
}

/// A fake [FuenteAutenticacion] for use-case tests.
class _FuenteAutenticacionFake implements FuenteAutenticacion {
  _FuenteAutenticacionFake({
    this.usuario,
    this.token,
    this.errorCodigo,
    this.errorMensaje,
  });

  final UsuarioRegistrado? usuario;
  final String? token;
  final String? errorCodigo;
  final String? errorMensaje;

  bool registroLlamado = false;

  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) {
    registroLlamado = true;
    if (usuario != null) return Future.value(usuario);
    return Future.error(AutenticacionException(errorCodigo!, errorMensaje!));
  }

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) {
    return Future.value(token ?? 'tok-default');
  }

  @override
  Future<Perfil> obtenerPerfil() {
    return Future.value(const Perfil(id: 'uuid-1', email: 'a@b.com'));
  }
}

/// A fake [ProveedorSesion] for use-case tests.
class _ProveedorSesionFake implements ProveedorSesion {
  _ProveedorSesionFake({this.alGuardar});

  final void Function(String)? alGuardar;

  String? guardado;

  @override
  Future<String?> obtenerToken() async => guardado;

  @override
  Future<void> guardarToken(String token) async {
    guardado = token;
    alGuardar?.call(token);
  }

  @override
  Future<void> cerrarSesion() async {
    guardado = null;
  }
}

/// A fake [ConsultaProgresoLocal] that records whether it was wiped.
class _ProgresoLocalFake implements ConsultaProgresoLocal {
  Set<int> completados = {};
  bool limpiado = false;

  @override
  Future<Set<int>> nivelesCompletados() async => completados;

  @override
  Future<int> mejorEstrellas(int idNivel) async => 0;

  @override
  Future<void> registrarCompletado({
    required int idNivel,
    required int estrellas,
  }) async {}

  @override
  Future<void> limpiar() async {
    limpiado = true;
    completados = {};
  }
}

/// A no-op [IColaSincronizacion] fake.
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
