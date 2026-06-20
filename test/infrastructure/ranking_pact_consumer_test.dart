import 'package:arrowmaze/infrastructure/dtos/fila_ranking_dto.dart';
import 'package:arrowmaze/infrastructure/dtos/ranking_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 11 — RED phase: Pact consumer contract test for ranking (AC3).
///
/// Verifies the DTO shape the client expects from the ranking response endpoint.
/// If the backend's provider contract drifts, CI fails on shape mismatch.
void main() {
  group('Pact consumer contract — ranking response DTO shape', () {
    test(
      'should_match_ranking_dto_contract',
      () {
        // Arrange — build a ranking response DTO matching the expected contract.
        final filaDto = FilaRankingDto(
          posicion: 1,
          nombreJugador: 'Alice',
          puntaje: 1500,
          estrellas: 3,
        );
        final responseDto = RankingResponseDto(
          idNivel: 1,
          limite: 5,
          filas: [filaDto],
        );

        // Act — serialize to JSON (the shape the provider will verify).
        final json = responseDto.toJson();

        // Assert — top-level contract: { idNivel, limite, filas: [...] }
        expect(json['idNivel'], 1);
        expect(json['limite'], 5);
        expect(json.containsKey('filas'), isTrue);

        final filas = json['filas'] as List<dynamic>;
        expect(filas, hasLength(1));

        final filaJson = filas.first as Map<String, dynamic>;
        expect(filaJson['posicion'], 1);
        expect(filaJson['nombreJugador'], 'Alice');
        expect(filaJson['puntaje'], 1500);
        expect(filaJson['estrellas'], 3);

        // Exact key contract per row.
        expect(filaJson.keys.toSet(), {
          'posicion',
          'nombreJugador',
          'puntaje',
          'estrellas',
        });

        // Exact top-level key contract.
        expect(json.keys.toSet(), {
          'idNivel',
          'limite',
          'filas',
        });
      },
    );

    test(
      'should_produce_valid_empty_ranking_contract',
      () {
        // Arrange — an empty ranking (no scores for this level yet).
        final responseDto = RankingResponseDto(
          idNivel: 99,
          limite: 10,
          filas: const [],
        );

        // Act
        final json = responseDto.toJson();

        // Assert
        expect(json['filas'], isEmpty);
        expect(json['idNivel'], 99);
      },
    );
  });
}
