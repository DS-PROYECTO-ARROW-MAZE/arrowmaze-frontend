import 'dart:convert';

import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/domain/niveles/celda_nivel.dart';
import 'package:arrowmaze/domain/niveles/definicion_nivel_remota.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
import 'package:arrowmaze/infrastructure/network/cliente_http_autenticado.dart';
import 'package:arrowmaze/infrastructure/niveles/niveles_data_source_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Issue 14 — RED: NivelesDataSourceHttp (`POST /levels`, protected) (AC2).
void main() {
  group('NivelesDataSourceHttp', () {
    test('should_post_contract_body_and_parse_created_level_when_creating', () async {
      // Arrange — capture the outgoing request; the interceptor adds the token.
      late http.Request enviada;
      final inner = MockClient((req) async {
        enviada = req;
        return http.Response(
          jsonEncode({'id': 'uuid-99', 'nombre': 'Nivel 1 - El Despertar'}),
          201,
        );
      });
      final fuente = NivelesDataSourceHttp(
        client: ClienteHttpAutenticado(
          inner: inner,
          proveedorSesion: _ProveedorSesionFake(token: 'tok-1'),
        ),
      );

      const definicion = DefinicionNivelRemota(
        nombre: 'Nivel 1 - El Despertar',
        dificultad: Dificultad.facil,
        ancho: 3,
        alto: 1,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 5,
        umbralEstrella1: 300,
        umbralEstrella2: 600,
        umbralEstrella3: 900,
        celdas: [
          [CeldaNivel(x: 0, y: 0, tipo: 'inicio')],
        ],
      );

      // Act
      final creado = await fuente.crear(definicion);

      // Assert — protected route carries the bearer token.
      expect(enviada.headers['Authorization'], 'Bearer tok-1');

      // Body matches the documented contract.
      final body = jsonDecode(enviada.body) as Map<String, dynamic>;
      expect(body['nombre'], 'Nivel 1 - El Despertar');
      expect(body['dificultad'], 'FACIL');
      expect(body['ancho'], 3);
      expect(body['alto'], 1);
      expect(body['baseNivel'], 1000);
      expect(body['kmov'], 10);
      expect(body['ktiempo'], 5);
      expect(body['umbralEstrella1'], 300);
      expect(body['umbralEstrella2'], 600);
      expect(body['umbralEstrella3'], 900);
      final celdas = body['celdas'] as List<dynamic>;
      final fila0 = celdas.first as List<dynamic>;
      final celda0 = fila0.first as Map<String, dynamic>;
      expect(celda0, {'x': 0, 'y': 0, 'tipo': 'inicio'});

      // Response parsed.
      expect(creado.id, 'uuid-99');
      expect(creado.nombre, 'Nivel 1 - El Despertar');
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
