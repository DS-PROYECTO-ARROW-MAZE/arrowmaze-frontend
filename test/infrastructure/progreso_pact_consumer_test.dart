import 'package:arrowmaze/infrastructure/dtos/progreso_sync_dto.dart';
import 'package:arrowmaze/infrastructure/dtos/sync_request_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 14 — consumer contract test for the batch sync payload (AC2/AC3).
///
/// Verifies the DTO shape the client sends to `POST /progress/sync`:
/// `{ "progresos": [ { nivelId, estrellas, movimientos, segundosRestantes,
/// completadoEn } ] }`.
void main() {
  group('Sync DTO shape (Issue 14)', () {
    test(
      'should_match_sync_dto_contract',
      () {
        // Arrange — a single progress item matching the contract.
        final item = ProgresoSyncDto(
          nivelId: 'uuid-1',
          estrellas: 3,
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
        expect(itemJson['estrellas'], 3);
        expect(itemJson['movimientos'], 12);
        expect(itemJson['segundosRestantes'], 55);
        expect(itemJson['completadoEn'], '2026-06-21T20:30:00.000Z');

        // Exact key contract per item.
        expect(itemJson.keys.toSet(), {
          'nivelId',
          'estrellas',
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
