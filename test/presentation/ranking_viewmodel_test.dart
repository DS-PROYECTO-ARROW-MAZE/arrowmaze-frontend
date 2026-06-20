import 'package:arrowmaze/application/ports/i_consulta_ranking.dart';
import 'package:arrowmaze/domain/ranking/fila_ranking.dart';
import 'package:arrowmaze/domain/ranking/ranking_dto.dart';
import 'package:arrowmaze/presentation/viewmodels/ranking_view_model.dart';
import 'package:arrowmaze/presentation/viewmodels/ranking_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 11 — RED phase: RankingViewModel (AC1, presentation).
///
/// Tests that the ViewModel correctly exposes ranking rows in its ViewState.
void main() {
  group('RankingViewModel', () {
    test(
      'should_expose_ranking_rows_in_viewstate_when_loaded',
      () async {
        // Arrange — a fake read port returning 2 rows.
        final port = _ConsultaRankingFake();
        final viewModel = RankingViewModel(consulta: port);

        // Act — load ranking for level 1, limit 2.
        await viewModel.cargarRanking(idNivel: 1, limite: 2);

        // Assert — ViewState has the rows.
        expect(viewModel.estado.status, RankingStatus.cargado);
        expect(viewModel.estado.filas, hasLength(2));
        expect(viewModel.estado.filas.first.posicion, 1);
        expect(viewModel.estado.filas.first.puntaje, 900);
        expect(viewModel.estado.filas.last.posicion, 2);
      },
    );

    test(
      'should_set_error_status_when_port_fails',
      () async {
        // Arrange — a port that throws.
        final port = _ConsultaRankingFakeError();
        final viewModel = RankingViewModel(consulta: port);

        // Act
        await viewModel.cargarRanking(idNivel: 1, limite: 5);

        // Assert
        expect(viewModel.estado.status, RankingStatus.error);
        expect(viewModel.estado.filas, isEmpty);
      },
    );
  });
}

class _ConsultaRankingFake implements IConsultaRanking {
  @override
  Future<RankingDto> obtenerTop(int idNivel, int limite) async {
    return RankingDto(
      filas: [
        FilaRanking(posicion: 1, nombreJugador: 'Alice', puntaje: 900, estrellas: 3),
        FilaRanking(posicion: 2, nombreJugador: 'Bob', puntaje: 700, estrellas: 2),
      ],
    );
  }
}

class _ConsultaRankingFakeError implements IConsultaRanking {
  @override
  Future<RankingDto> obtenerTop(int idNivel, int limite) async {
    throw Exception('Network error');
  }
}
