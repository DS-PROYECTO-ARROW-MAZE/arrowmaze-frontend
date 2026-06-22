import 'dart:async';

import 'package:arrowmaze/application/ports/i_consulta_ranking.dart';
import 'package:arrowmaze/domain/ranking/fila_ranking.dart';
import 'package:arrowmaze/domain/ranking/ranking_dto.dart';
import 'package:arrowmaze/presentation/viewmodels/ranking_view_model.dart';
import 'package:arrowmaze/presentation/viewmodels/ranking_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 14 / 15 — RankingViewModel: read-only, reloadable.
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
      'should_refresh_rankings_when_cargarRanking_called_again',
      () async {
        // Arrange — initial load with 2 entries.
        final port = _ConsultaRankingFake();
        final viewModel = RankingViewModel(consulta: port);
        await viewModel.cargarRanking(nivelId: 'uuid-1', limite: 2);
        expect(viewModel.estado.entradas, hasLength(2));

        // Reconfigure the fake to return different data.
        port.entradas = [
          FilaRanking(
            email: 'new@b.com',
            puntaje: 1200,
            estrellas: 3,
            movimientos: 8,
            segundosRestantes: 82,
            completadoEn: DateTime.utc(2026, 6, 22),
          ),
        ];

        // Act — refresh (simulating post-sync reload).
        await viewModel.cargarRanking(nivelId: 'uuid-1', limite: 5);

        // Assert — state reflects the new data.
        expect(viewModel.estado.status, RankingStatus.cargado);
        expect(viewModel.estado.entradas, hasLength(1));
        expect(viewModel.estado.entradas.first.puntaje, 1200);
        expect(viewModel.estado.entradas.first.email, 'new@b.com');
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

    test(
      'should_await_pending_sync_before_fetching_leaderboard',
      () async {
        // Arrange — the leaderboard read must not start until the in-flight
        // POST /progress/sync has resolved (no read-before-write race).
        final port = _ConsultaRankingFake();
        final viewModel = RankingViewModel(consulta: port);
        final syncCompleter = Completer<bool>();

        // Act — kick off the load with an unresolved sync future.
        final carga = viewModel.cargarRanking(
          nivelId: 'uuid-1',
          limite: 2,
          sincronizacionPendiente: syncCompleter.future,
        );
        // Let microtasks drain; the fetch must still be blocked on the sync.
        await Future(() {});

        // Assert — no fetch happened yet because the sync is still pending.
        expect(port.llamadas, 0,
            reason: 'Leaderboard must wait for the sync to resolve first');

        // Resolve the sync; now the fetch may proceed.
        syncCompleter.complete(true);
        await carga;

        expect(port.llamadas, 1);
        expect(viewModel.estado.status, RankingStatus.cargado);
        expect(viewModel.estado.mensajeAdvertencia, isNull);
      },
    );

    test(
      'should_warn_but_still_load_when_pending_sync_failed',
      () async {
        // Arrange — the in-flight sync resolves to false (upload failed, e.g.
        // 401/400). The board still loads, but with a non-blocking warning.
        final port = _ConsultaRankingFake();
        final viewModel = RankingViewModel(consulta: port);

        // Act
        await viewModel.cargarRanking(
          nivelId: 'uuid-1',
          limite: 2,
          sincronizacionPendiente: Future<bool>.value(false),
        );

        // Assert — leaderboard shown, warning surfaced rather than silent stale.
        expect(viewModel.estado.status, RankingStatus.cargado);
        expect(viewModel.estado.entradas, hasLength(2));
        expect(viewModel.estado.mensajeAdvertencia, isNotNull);
      },
    );
  });
}

class _ConsultaRankingFake implements IConsultaRanking {
  _ConsultaRankingFake();

  List<FilaRanking> entradas = [
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
  ];

  /// Number of times the leaderboard read was invoked — used to assert the
  /// fetch is ordered after the pending sync.
  int llamadas = 0;

  @override
  Future<RankingDto> obtenerTop(String nivelId, int limite) async {
    llamadas++;
    return RankingDto(entradas: List.of(entradas));
  }
}

class _ConsultaRankingFakeError implements IConsultaRanking {
  @override
  Future<RankingDto> obtenerTop(String nivelId, int limite) async {
    throw Exception('Network error');
  }
}
