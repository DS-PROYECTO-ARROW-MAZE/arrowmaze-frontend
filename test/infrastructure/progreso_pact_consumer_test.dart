import 'package:arrowmaze/infrastructure/dtos/progreso_sync_dto.dart';
import 'package:arrowmaze/infrastructure/dtos/sync_request_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Consumer contract test for the batch sync payload.
///
/// Verifies the DTO shape the client sends to `POST /progress/sync` matches the
/// backend `SincronizarProgresoRequestDto` exactly:
/// `{ "progresos": [ { nivelId, movimientos, segundosRestantes, completadoEn } ] }`.
///
/// The backend runs with `forbidNonWhitelisted: true` (Ticket 19 / ADR-0005), so
/// the item must NOT carry a client-computed `estrellas` (the server recomputes
/// the score). An earlier version of this test asserted `estrellas` was present —
/// that encoded the wrong contract and let the 400 bug ship green.
void main() {
  group('Sync DTO shape', () {
    test(
      'should_match_sync_dto_contract',
      () {
        // Arrange — a single progress item matching the contract.
        final item = ProgresoSyncDto(
          nivelId: 'uuid-1',
          movimientos: 12,
          segundosRestantes: 55,
          completadoEn: '2026-06-21T20:30:00.000Z',
        );
        final syncDto = SyncRequestDto(progresos: [item]);

        // Act
        final json = syncDto.toJson();

        // Assert — envelope key is `progresos`.
        expect(json.containsKey('progresos'), isTrue);
        final progresos = json['progresos'] as List<dynamic>;
        expect(progresos, hasLength(1));

        final itemJson = progresos.first as Map<String, dynamic>;
        expect(itemJson['nivelId'], 'uuid-1');
        expect(itemJson['movimientos'], 12);
        expect(itemJson['segundosRestantes'], 55);
        expect(itemJson['completadoEn'], '2026-06-21T20:30:00.000Z');

        // Exact key contract per item — no extra fields (notably no `estrellas`),
        // which the backend whitelist would reject.
        expect(itemJson.keys.toSet(), {
          'nivelId',
          'movimientos',
          'segundosRestantes',
          'completadoEn',
        });
      },
    );

    test(
      'should_produce_valid_empty_batch_contract',
      () {
        // Arrange
        final syncDto = SyncRequestDto(progresos: const []);

        // Act
        final json = syncDto.toJson();

        // Assert
        expect(json['progresos'], isEmpty);
      },
    );
  });
}
