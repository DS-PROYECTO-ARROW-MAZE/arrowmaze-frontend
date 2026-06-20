import 'package:flutter/foundation.dart';

import '../../application/ports/i_consulta_ranking.dart';
import '../../domain/ranking/fila_ranking.dart';
import 'ranking_view_state.dart';

/// The View's only collaborator for leaderboard reads (DM-B5, E3).
///
/// Manages the ranking lifecycle: loads top-N per level, exposes
/// [RankingViewState] snapshots. The View never calls the port directly (MVVM).
/// Read-only — no write path (AC2).
class RankingViewModel extends ChangeNotifier {
  /// Creates the ranking ViewModel with an injected read port.
  RankingViewModel({required IConsultaRanking consulta})
      : _consulta = consulta;

  final IConsultaRanking _consulta;

  RankingViewState _estado = const RankingViewState();

  /// The current immutable state the View renders.
  RankingViewState get estado => _estado;

  /// Loads the top [limite] scores for level [idNivel].
  Future<void> cargarRanking({
    required int idNivel,
    required int limite,
  }) async {
    _estado = _estado.copyWith(
      idNivel: idNivel,
      status: RankingStatus.cargando,
      mensajeError: null,
    );
    notifyListeners();

    try {
      final dto = await _consulta.obtenerTop(idNivel, limite);
      _estado = _estado.copyWith(
        status: RankingStatus.cargado,
        filas: dto.filas,
      );
    } catch (e) {
      _estado = _estado.copyWith(
        status: RankingStatus.error,
        filas: <FilaRanking>[],
        mensajeError: 'Could not load leaderboard.',
      );
    }

    notifyListeners();
  }
}
