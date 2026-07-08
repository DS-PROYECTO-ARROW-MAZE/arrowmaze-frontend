import 'dart:convert';

import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/domain/progreso/run_completado.dart';
import 'package:arrowmaze/infrastructure/network/cliente_http_autenticado.dart';
import 'package:arrowmaze/infrastructure/progreso/progreso_data_source_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Issue 14 — ProgresoDataSourceHttp (`POST /progress/sync`, protected) (AC2/AC3).
void main() {
  group('ProgresoDataSourceHttp (Issue 14)', () {
    test('should_post_progresos_batch_with_bearer_and_return_true_when_uploading', () async {
      // Arrange
      late http.Request enviada;
      final inner = MockClient((req) async {
        enviada = req;
        return http.Response(jsonEncode({'guardados': 1}), 201);
      });
      final fuente = ProgresoDataSourceHttp(
        client: ClienteHttpAutenticado(
          inner: inner,
          proveedorSesion: _ProveedorSesionFake(token: 'tok-9'),
        ),
      );

      final runs = [
        RunCompletado(
          nivelId: 'uuid-1',
          movimientos: 12,
          segundosRestantes: 55,
          completadoEn: DateTime.utc(2026, 6, 21, 20, 30),
        ),
      ];

      // Act
      final ok = await fuente.guardarLote(runs);

      // Assert
      expect(ok, isTrue);
      expect(enviada.headers['Authorization'], 'Bearer tok-9');
      final body = jsonDecode(enviada.body) as Map<String, dynamic>;
      final progresos = body['progresos'] as List<dynamic>;
      final item = progresos.first as Map<String, dynamic>;
      expect(item['nivelId'], 'uuid-1');
      expect(item['movimientos'], 12);
      expect(item['segundosRestantes'], 55);
      expect(item['completadoEn'], '2026-06-21T20:30:00.000Z');
      // No client-side score is sent — the backend whitelist would 400 on it.
      expect(item.containsKey('estrellas'), isFalse);
    });

    test('should_return_false_when_server_errors', () async {
      // Arrange
      final fuente = ProgresoDataSourceHttp(
        client: ClienteHttpAutenticado(
          inner: MockClient((req) async => http.Response('boom', 500)),
          proveedorSesion: _ProveedorSesionFake(token: 'tok'),
        ),
      );

      // Act
      final ok = await fuente.guardarLote([
        RunCompletado(
          nivelId: 'uuid-1',
          movimientos: 4,
          segundosRestantes: null,
          completadoEn: DateTime.utc(2026),
        ),
      ]);

      // Assert
      expect(ok, isFalse);
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
