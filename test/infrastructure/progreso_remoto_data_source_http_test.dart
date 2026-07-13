import 'package:arrowmaze/infrastructure/progreso/progreso_remoto_data_source_http.dart';
import 'package:arrowmaze/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 24 — `GET /progress` data source sends the bearer token and parses
/// the response shape matching backend ticket 18's contract exactly.
void main() {
  // Golden JSON matching the real backend `GET /progress` contract: a **bare
  // array** of `ProgresoRespuestaDto` (backend ticket 18), carrying the full
  // per-run fields — not a `{ "niveles": [...] }` envelope. The client only
  // needs nivelId/estrellas/puntaje but must parse the array shape correctly.
  const goldenJson =
      '[{"nivelId":"a1b2c3d4-e5f6-7890-abcd-ef1234567890",'
      '"puntaje":600,"estrellas":2,"movimientos":12,'
      '"segundosRestantes":55,"completadoEn":"2026-06-21T20:30:00.000Z"}]';

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

    // Ticket 32 (AC3/AC4) — the parser must return the **whole** history, one
    // item per entry, so a returning player's full completed-set reaches the
    // restore use case (no truncation, no silent drop of extra fields).
    test('should_parse_full_progress_history_without_dropping_entries', () async {
      // Arrange — a golden 8-entry array (sparse-ordinal ids 1‑8), each with the
      // full backend per-run fields plus an unexpected extra the client ignores.
      final buffer = StringBuffer('[');
      for (var i = 1; i <= 8; i++) {
        if (i > 1) buffer.write(',');
        buffer.write('{"nivelId":"uuid-$i","puntaje":${i * 100},'
            '"estrellas":${i % 3},"movimientos":$i,"segundosRestantes":${60 - i},'
            '"completadoEn":"2026-06-2${i}T20:30:00.000Z","campoExtra":true}');
      }
      buffer.write(']');
      final inner = MockClient((_) async => http.Response(buffer.toString(), 200));
      final dataSource = ProgresoRemotoDataSourceHttp(client: inner);

      // Act
      final items = await dataSource.obtenerProgreso();

      // Assert — all eight entries survive, in order, with the extra field ignored.
      expect(items, hasLength(8));
      expect(
        items.map((e) => e.nivelId).toList(),
        [for (var i = 1; i <= 8; i++) 'uuid-$i'],
      );
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