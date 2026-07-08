import 'package:arrowmaze/infrastructure/progreso/progreso_remoto_data_source_http.dart';
import 'package:arrowmaze/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 24 — `GET /progress` data source sends the bearer token and parses
/// the response shape matching backend ticket 18's contract exactly.
void main() {
  const goldenJson =
      '{"niveles":[{"nivelId":"a1b2c3d4-e5f6-7890-abcd-ef1234567890",'
      '"estrellas":2,"puntaje":600}]}';

  group('ProgresoRemotoDataSourceHttp (Ticket 24 — GET /progress)', () {
    test('should_send_authorization_header_and_parse_response_when_getting_progress',
        () async {
      // Arrange — capture the outgoing request.
      late http.BaseRequest capturada;
      final inner = MockClient((req) async {
        capturada = req;
        return http.Response(goldenJson, 200);
      });
      final dataSource = ProgresoRemotoDataSourceHttp(client: inner);

      // Act
      final items = await dataSource.obtenerProgreso();

      // Assert — the request hit the right endpoint.
      expect(
        capturada.url.toString(),
        '${ApiConfig.baseUrl}${ApiConfig.progressPath}',
      );

      // Assert — the items are parsed correctly.
      expect(items, hasLength(1));
      expect(items[0].nivelId, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(items[0].estrellas, 2);
      expect(items[0].puntaje, 600);
    });

    test('should_return_empty_list_when_status_is_not_200', () async {
      // Arrange
      final inner = MockClient((_) async => http.Response('', 401));
      final dataSource = ProgresoRemotoDataSourceHttp(client: inner);

      // Act
      final items = await dataSource.obtenerProgreso();

      // Assert — graceful degradation, no throw.
      expect(items, isEmpty);
    });

    test('should_return_empty_list_when_network_fails', () async {
      // Arrange
      final inner = MockClient((_) async => throw Exception('no network'));
      final dataSource = ProgresoRemotoDataSourceHttp(client: inner);

      // Act
      final items = await dataSource.obtenerProgreso();

      // Assert — graceful degradation, no throw.
      expect(items, isEmpty);
    });

    test('should_map_dto_fields_to_domain_value_object_when_parsing', () async {
      // Arrange
      final inner = MockClient(
        (_) async => http.Response(goldenJson, 200),
      );
      final dataSource = ProgresoRemotoDataSourceHttp(client: inner);

      // Act
      final items = await dataSource.obtenerProgreso();

      // Assert — shape matches backend ticket 18 contract field-by-field.
      final item = items.single;
      expect(item.nivelId, isA<String>());
      expect(item.estrellas, isA<int>());
      expect(item.puntaje, isA<int>());
      // The DTO has no extra fields the backend doesn't send.
    });
  });
}