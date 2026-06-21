import 'package:arrowmaze/application/ports/i_consulta_ranking.dart';
import 'package:arrowmaze/domain/ranking/fila_ranking.dart';
import 'package:arrowmaze/domain/ranking/ranking_dto.dart';
import 'package:arrowmaze/presentation/viewmodels/ranking_view_model.dart';
import 'package:arrowmaze/presentation/viewmodels/ranking_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 14 — RankingViewModel (String nivelId, `entradas`).
void main() {
  group('RankingViewModel', () {
    test(
      'should_expose_ranking_rows_in_viewstate_when_loaded',
      () async {
        // Arrange
        final port = _ConsultaRankingFake();
        final viewModel = RankingViewModel(consulta: port);

        // Act
        await viewModel.cargarRanking(nivelId: 'uuid-1', limite: 2);

        // Assert
        expect(viewModel.estado.status, RankingStatus.cargado);
        expect(viewModel.estado.entradas, hasLength(2));
        expect(viewModel.estado.entradas.first.puntaje, 900);
        expect(viewModel.estado.entradas.first.email, 'alice@b.com');
      },
    );

    test(
      'should_set_error_status_when_port_fails',
      () async {
        // Arrange
        final port = _ConsultaRankingFakeError();
        final viewModel = RankingViewModel(consulta: port);

        // Act
        await viewModel.cargarRanking(nivelId: 'uuid-1', limite: 5);

        // Assert
        expect(viewModel.estado.status, RankingStatus.error);
        expect(viewModel.estado.entradas, isEmpty);
      },
    );
  });
}

class _ConsultaRankingFake implements IConsultaRanking {
  @override
  Future<RankingDto> obtenerTop(String nivelId, int limite) async {
    return RankingDto(
      entradas: [
        FilaRanking(
          email: 'alice@b.com',
          puntaje: 900,
          estrellas: 3,
          movimientos: 12,
          segundosRestantes: null,
          completadoEn: DateTime.utc(2026, 6, 21),
        ),
        FilaRanking(
          email: 'bob@b.com',
          puntaje: 700,
          estrellas: 2,
          movimientos: 18,
          segundosRestantes: 5,
          completadoEn: DateTime.utc(2026, 6, 21),
        ),
      ],
    );
  }
}

class _ConsultaRankingFakeError implements IConsultaRanking {
  @override
  Future<RankingDto> obtenerTop(String nivelId, int limite) async {
    throw Exception('Network error');
  }
}
