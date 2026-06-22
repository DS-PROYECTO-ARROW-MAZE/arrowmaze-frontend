import 'dart:convert';

import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/infrastructure/network/cliente_http_autenticado.dart';
import 'package:arrowmaze/infrastructure/ranking/ranking_data_source_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Issue 14 — RankingDataSourceHttp (`GET /leaderboard`, protected) (AC2/AC3).
void main() {
  group('RankingDataSourceHttp (Issue 14)', () {
    test('should_query_leaderboard_with_nivelId_and_limite', () async {
      // Arrange
      late Uri pedida;
      late http.BaseRequest enviada;
      final inner = MockClient((req) async {
        pedida = req.url;
        enviada = req;
        return http.Response(
          jsonEncode({
            'entradas': [
              {
                'puntaje': 880,
                'estrellas': 3,
                'movimientos': 12,
                'segundosRestantes': null,
                'completadoEn': '2026-06-21T20:30:00.000Z',
                'email': 'a@b.com',
              },
            ],
          }),
          200,
        );
      });
      final fuente = RankingDataSourceHttp(
        client: ClienteHttpAutenticado(
          inner: inner,
          proveedorSesion: _ProveedorSesionFake(token: 'tok-r'),
        ),
      );

      // Act
      final dto = await fuente.obtenerTop('uuid-1', 10);

      // Assert — endpoint, query params and bearer token.
      expect(pedida.path, '/leaderboard');
      // Backend contract is `GET /leaderboard?idNivel=UUID&limite=N`
      // (see arrowmaze-backend leaderboard/progress e2e specs).
      expect(pedida.queryParameters['idNivel'], 'uuid-1');
      expect(pedida.queryParameters['limite'], '10');
      expect(enviada.headers['Authorization'], 'Bearer tok-r');

      // Parsed entry.
      expect(dto.entradas, hasLength(1));
      expect(dto.entradas.first.email, 'a@b.com');
      expect(dto.entradas.first.puntaje, 880);
      expect(dto.entradas.first.segundosRestantes, isNull);
    });

    test('should_return_empty_when_server_errors', () async {
      // Arrange
      final fuente = RankingDataSourceHttp(
        client: ClienteHttpAutenticado(
          inner: MockClient((req) async => http.Response('nope', 500)),
          proveedorSesion: _ProveedorSesionFake(token: 'tok'),
        ),
      );

      // Act
      final dto = await fuente.obtenerTop('uuid-1', 10);

      // Assert
      expect(dto.entradas, isEmpty);
    });
  });
}

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
