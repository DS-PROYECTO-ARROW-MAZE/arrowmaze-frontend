import 'package:arrowmaze/application/ports/fuente_autenticacion.dart';
import 'package:arrowmaze/application/use_cases/obtener_perfil_use_case.dart';
import 'package:arrowmaze/domain/sesion/perfil.dart';
import 'package:arrowmaze/domain/sesion/usuario_registrado.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 14 — RED: ObtenerPerfilUseCase (`GET /auth/me`).
///
/// Reads the authenticated principal through the port. The Bearer header is the
/// interceptor's job, invisible to this use case.
void main() {
  group('ObtenerPerfilUseCase', () {
    test('should_return_principal_when_me_succeeds', () async {
      // Arrange
      final port = _FuenteAutenticacionFake(
        perfil: const Perfil(id: 'uuid-7', email: 'me@b.com'),
      );
      final useCase = ObtenerPerfilUseCase(fuenteAutenticacion: port);

      // Act
      final perfil = await useCase.ejecutar();

      // Assert
      expect(perfil.id, 'uuid-7');
      expect(perfil.email, 'me@b.com');
    });
  });
}

class _FuenteAutenticacionFake implements FuenteAutenticacion {
  _FuenteAutenticacionFake({required this.perfil});

  final Perfil perfil;

  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) =>
      Future.value(
        UsuarioRegistrado(id: 'x', email: email, createdAt: DateTime.utc(2026)),
      );

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) =>
      Future.value('tok');

  @override
  Future<Perfil> obtenerPerfil() => Future.value(perfil);
}
