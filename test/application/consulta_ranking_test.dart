import 'package:arrowmaze/application/ports/i_consulta_ranking.dart';
import 'package:arrowmaze/application/use_cases/consultar_ranking_use_case.dart';
import 'package:arrowmaze/domain/ranking/fila_ranking.dart';
import 'package:arrowmaze/domain/ranking/ranking_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 11 — RED phase: ConsultarRankingUseCase (AC1).
///
/// Tests the read-only use case via a fake port — no HTTP, no Flutter.
void main() {
  group('ConsultarRankingUseCase', () {
    test(
      'should_return_top_n_for_level_when_obtenerTop_called',
      () async {
        // Arrange — a fake read port returning 3 rows.
        final port = _ConsultaRankingFake();
        final useCase = ConsultarRankingUseCase(consulta: port);

        // Act
        final resultado = await useCase.obtenerTop(idNivel: 1, limite: 3);

        // Assert — returns the top-N ranking from the port (AC1).
        expect(resultado.filas, hasLength(3));
        expect(resultado.filas.first.puntaje, 1500);
        expect(resultado.filas.first.posicion, 1);
        expect(resultado.filas.last.posicion, 3);
      },
    );

    test(
      'should_return_empty_ranking_when_no_scores',
      () async {
        // Arrange — a port with no data.
        final port = _ConsultaRankingFake(sinDatos: true);
        final useCase = ConsultarRankingUseCase(consulta: port);

        // Act
        final resultado = await useCase.obtenerTop(idNivel: 99, limite: 10);

        // Assert
        expect(resultado.filas, isEmpty);
      },
    );
  });
}

/// Fake read-only port for testing.
class _ConsultaRankingFake implements IConsultaRanking {
  _ConsultaRankingFake({this.sinDatos = false});

  final bool sinDatos;

  @override
  Future<RankingDto> obtenerTop(int idNivel, int limite) async {
    if (sinDatos) return const RankingDto(filas: []);
    return RankingDto(
      filas: List.generate(
        limite,
        (i) => FilaRanking(
          posicion: i + 1,
          nombreJugador: 'Player ${i + 1}',
          puntaje: 1500 - i * 200,
          estrellas: 3 - i,
        ),
      ),
    );
  }
}
