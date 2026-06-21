import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/infrastructure/network/cliente_http_autenticado.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 14 — RED: the Bearer HTTP interceptor (AC3).
///
/// [ClienteHttpAutenticado] must transparently attach
/// `Authorization: Bearer <token>` to every outgoing request when a session
/// token exists, reading it through the injected [ProveedorSesion]. With no
/// token it must leave the request untouched (public routes still work).
void main() {
  group('ClienteHttpAutenticado (AC3 — interceptor)', () {
    test(
      'should_attach_bearer_header_when_token_exists',
      () async {
        // Arrange — capture the request the inner client actually receives.
        late http.BaseRequest capturada;
        final inner = MockClient((req) async {
          capturada = req;
          return http.Response('{}', 200);
        });
        final cliente = ClienteHttpAutenticado(
          inner: inner,
          proveedorSesion: _ProveedorSesionFake(token: 'tok-123'),
        );

        // Act
        await cliente.get(Uri.parse('http://localhost:3000/auth/me'));

        // Assert — the interceptor injected the bearer header.
        expect(capturada.headers['Authorization'], 'Bearer tok-123');
      },
    );

    test(
      'should_not_attach_header_when_no_token',
      () async {
        // Arrange
        late http.BaseRequest capturada;
        final inner = MockClient((req) async {
          capturada = req;
          return http.Response('{}', 200);
        });
        final cliente = ClienteHttpAutenticado(
          inner: inner,
          proveedorSesion: _ProveedorSesionFake(token: null),
        );

        // Act
        await cliente.get(Uri.parse('http://localhost:3000/leaderboard'));

        // Assert — no auth header is forged when the user is signed out.
        expect(capturada.headers.containsKey('Authorization'), isFalse);
      },
    );

    test(
      'should_preserve_existing_headers_when_attaching_token',
      () async {
        // Arrange
        late http.BaseRequest capturada;
        final inner = MockClient((req) async {
          capturada = req;
          return http.Response('{}', 201);
        });
        final cliente = ClienteHttpAutenticado(
          inner: inner,
          proveedorSesion: _ProveedorSesionFake(token: 'tok-xyz'),
        );

        // Act
        await cliente.post(
          Uri.parse('http://localhost:3000/levels'),
          headers: {'Content-Type': 'application/json'},
          body: '{}',
        );

        // Assert — the caller's headers survive alongside the injected one.
        expect(capturada.headers['Content-Type'], contains('application/json'));
        expect(capturada.headers['Authorization'], 'Bearer tok-xyz');
      },
    );
  });
}

/// A fake [ProveedorSesion] returning a fixed token (or none).
class _ProveedorSesionFake implements ProveedorSesion {
  _ProveedorSesionFake({this.token});

  final String? token;

  @override
  Future<String?> obtenerToken() async => token;

  @override
  Future<void> guardarToken(String token) async {}

  @override
  Future<void> cerrarSesion() async {}
}
