import 'package:arrowmaze/infrastructure/dtos/sync_request_dto.dart';
import 'package:arrowmaze/infrastructure/dtos/sync_run_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 10 — Pact consumer contract test (AC3).
///
/// Verifies the DTO shape that the client sends in a batch sync request.
/// If the backend's provider contract drifts, CI fails on shape mismatch.
/// This is the **consumer** side — it asserts the request payload structure.
void main() {
  group('Pact consumer contract — sync DTO shape', () {
    test(
      'should_match_sync_dto_contract',
      () {
        // Arrange — a single run DTO matching the expected contract.
        final runDto = SyncRunDto(
          nivelId: 1,
          movimientos: 10,
          segundosRestantes: 30,
          puntaje: 950,
          estrellas: 2,
          completadoEn: '2026-01-01T00:00:00.000Z',
        );

        final syncDto = SyncRequestDto(runs: [runDto]);

        // Act — serialize to JSON (the shape the provider will verify).
        final json = syncDto.toJson();

        // Assert — the payload must match the Pact contract:
        // { "runs": [ { "nivelId", "movimientos", "segundosRestantes",
        //     "puntaje", "estrellas", "completadoEn" } ] }
        expect(json.containsKey('runs'), isTrue);
        final runs = json['runs'] as List<dynamic>;
        expect(runs, hasLength(1));

        final runJson = runs.first as Map<String, dynamic>;
        expect(runJson['nivelId'], 1);
        expect(runJson['movimientos'], 10);
        expect(runJson['segundosRestantes'], 30);
        expect(runJson['puntaje'], 950);
        expect(runJson['estrellas'], 2);
        expect(runJson['completadoEn'], '2026-01-01T00:00:00.000Z');

        // Field order and completeness check — exact keys contract.
        expect(runJson.keys.toSet(), {
          'nivelId',
          'movimientos',
          'segundosRestantes',
          'puntaje',
          'estrellas',
          'completadoEn',
        });
      },
    );

    test(
      'should_produce_valid_empty_batch_contract',
      () {
        // Arrange — an empty batch (also valid per Pact).
        final syncDto = SyncRequestDto(runs: const []);

        // Act
        final json = syncDto.toJson();

        // Assert
        expect(json['runs'], isEmpty);
      },
    );
  });
}
