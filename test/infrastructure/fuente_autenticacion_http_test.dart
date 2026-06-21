import 'dart:convert';

import 'package:arrowmaze/application/ports/fuente_autenticacion.dart';
import 'package:arrowmaze/core/errors/auth_errors.dart';
import 'package:arrowmaze/infrastructure/datasources/fuente_autenticacion_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Issue 14 — RED: FuenteAutenticacionHttp against the real contract (AC2).
///
/// Exercises request shape, response parsing and error mapping with a mocked
/// transport — no real network.
void main() {
  group('FuenteAutenticacionHttp (Issue 14)', () {
    test('should_send_email_password_and_parse_user_on_register', () async {
      // Arrange
      late http.Request enviada;
      final fuente = FuenteAutenticacionHttp(
        client: MockClient((req) async {
          enviada = req;
          return http.Response(
            jsonEncode({
              'message': 'created',
              'user': {
                'id': 'uuid-1',
                'email': 'a@b.com',
                'createdAt': '2026-06-21T00:00:00.000Z',
              },
            }),
            201,
          );
        }),
      );

      // Act
      final usuario =
          await fuente.registrar(email: 'a@b.com', password: 'secret');

      // Assert — request body carries only email + password.
      final body = jsonDecode(enviada.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'email', 'password'});
      expect(body['email'], 'a@b.com');
      // Response parsed into the domain entity.
      expect(usuario.id, 'uuid-1');
      expect(usuario.email, 'a@b.com');
    });

    test('should_throw_email_duplicate_when_register_conflicts', () async {
      // Arrange — NestJS returns 409 on a duplicate email.
      final fuente = FuenteAutenticacionHttp(
        client: MockClient((req) async {
          return http.Response(
            jsonEncode({'message': 'Email already registered', 'statusCode': 409}),
            409,
          );
        }),
      );

      // Act / Assert
      expect(
        () => fuente.registrar(email: 'dupe@b.com', password: 'secret'),
        throwsA(
          isA<AutenticacionException>().having(
            (e) => e.codigo,
            'codigo',
            AuthErrorCode.emailDuplicado,
          ),
        ),
      );
    });

    test('should_return_token_on_login', () async {
      // Arrange
      final fuente = FuenteAutenticacionHttp(
        client: MockClient((req) async {
          return http.Response(jsonEncode({'token': 'jwt-xyz'}), 200);
        }),
      );

      // Act
      final token = await fuente.iniciarSesion(email: 'a@b.com', password: 'p');

      // Assert
      expect(token, 'jwt-xyz');
    });

    test('should_throw_invalid_credentials_when_login_401', () async {
      // Arrange
      final fuente = FuenteAutenticacionHttp(
        client: MockClient((req) async {
          return http.Response(jsonEncode({'message': 'bad'}), 401);
        }),
      );

      // Act / Assert
      expect(
        () => fuente.iniciarSesion(email: 'a@b.com', password: 'wrong'),
        throwsA(
          isA<AutenticacionException>().having(
            (e) => e.codigo,
            'codigo',
            AuthErrorCode.credencialesInvalidas,
          ),
        ),
      );
    });

    test('should_parse_principal_on_obtenerPerfil', () async {
      // Arrange
      final fuente = FuenteAutenticacionHttp(
        client: MockClient((req) async {
          expect(req.url.path, '/auth/me');
          return http.Response(
            jsonEncode({
              'principal': {'id': 'uuid-9', 'email': 'me@b.com'},
            }),
            200,
          );
        }),
      );

      // Act
      final perfil = await fuente.obtenerPerfil();

      // Assert
      expect(perfil.id, 'uuid-9');
      expect(perfil.email, 'me@b.com');
    });
  });
}
