import 'package:arrowmaze/application/ports/i_consulta_ranking.dart';
import 'package:arrowmaze/application/use_cases/consultar_ranking_use_case.dart';
import 'package:arrowmaze/domain/ranking/fila_ranking.dart';
import 'package:arrowmaze/domain/ranking/ranking_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 14 — ConsultarRankingUseCase (read-only, String nivelId).
void main() {
  group('ConsultarRankingUseCase', () {
    test(
      'should_return_top_n_for_level_when_obtenerTop_called',
      () async {
        // Arrange
        final port = _ConsultaRankingFake();
        final useCase = ConsultarRankingUseCase(consulta: port);

        // Act
        final resultado = await useCase.obtenerTop(nivelId: 'uuid-1', limite: 3);

        // Assert
        expect(resultado.entradas, hasLength(3));
        expect(resultado.entradas.first.puntaje, 1500);
      },
    );

    test(
      'should_return_empty_ranking_when_no_scores',
      () async {
        // Arrange
        final port = _ConsultaRankingFake(sinDatos: true);
        final useCase = ConsultarRankingUseCase(consulta: port);

        // Act
        final resultado = await useCase.obtenerTop(nivelId: 'uuid-9', limite: 10);

        // Assert
        expect(resultado.entradas, isEmpty);
      },
    );
  });
}

/// Fake read-only port for testing.
class _ConsultaRankingFake implements IConsultaRanking {
  _ConsultaRankingFake({this.sinDatos = false});

  final bool sinDatos;

  @override
  Future<RankingDto> obtenerTop(String nivelId, int limite) async {
    if (sinDatos) return const RankingDto(entradas: []);
    return RankingDto(
      entradas: List.generate(
        limite,
        (i) => FilaRanking(
          email: 'player$i@b.com',
          puntaje: 1500 - i * 200,
          estrellas: 3 - i,
          movimientos: 10 + i,
          segundosRestantes: null,
          completadoEn: DateTime.utc(2026, 6, 21),
        ),
      ),
    );
  }
}
