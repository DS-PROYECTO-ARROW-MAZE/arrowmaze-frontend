import 'package:arrowmaze/infrastructure/dtos/fila_ranking_dto.dart';
import 'package:arrowmaze/infrastructure/dtos/ranking_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 14 — consumer contract test for the leaderboard response (AC2/AC3).
///
/// Verifies the DTO shape the client expects from `GET /leaderboard`:
/// `{ "entradas": [ { puntaje, estrellas, movimientos, segundosRestantes,
/// completadoEn, email } ] }`.
void main() {
  group('Leaderboard DTO shape (Issue 14)', () {
    test(
      'should_match_ranking_dto_contract_when_serialized',
      () {
        // Arrange
        final entrada = FilaRankingDto(
          puntaje: 880,
          estrellas: 3,
          movimientos: 12,
          segundosRestantes: null,
          completadoEn: '2026-06-21T20:30:00.000Z',
          email: 'a@b.com',
        );
        final responseDto = RankingResponseDto(entradas: [entrada]);

        // Act
        final json = responseDto.toJson();

        // Assert — envelope key is `entradas`.
        expect(json.containsKey('entradas'), isTrue);
        final entradas = json['entradas'] as List<dynamic>;
        expect(entradas, hasLength(1));

        final filaJson = entradas.first as Map<String, dynamic>;
        expect(filaJson['puntaje'], 880);
        expect(filaJson['estrellas'], 3);
        expect(filaJson['movimientos'], 12);
        expect(filaJson['segundosRestantes'], isNull);
        expect(filaJson['completadoEn'], '2026-06-21T20:30:00.000Z');
        expect(filaJson['email'], 'a@b.com');

        // Exact key contract per row.
        expect(filaJson.keys.toSet(), {
          'puntaje',
          'estrellas',
          'movimientos',
          'segundosRestantes',
          'completadoEn',
          'email',
        });
      },
    );

    test(
      'should_produce_valid_empty_ranking_contract_when_ranking_is_empty',
      () {
        // Arrange
        final responseDto = RankingResponseDto(entradas: const []);

        // Act
        final json = responseDto.toJson();

        // Assert
        expect(json['entradas'], isEmpty);
      },
    );
  });
}
