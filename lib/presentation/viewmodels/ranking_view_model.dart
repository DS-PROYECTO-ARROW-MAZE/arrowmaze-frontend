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

  /// Loads the top [limite] scores for level [nivelId].
  ///
  /// When [sincronizacionPendiente] is supplied (the in-flight upload of a run
  /// just completed), it is awaited **before** the leaderboard is fetched, so
  /// the read never races the `POST /progress/sync` write and the score just
  /// earned is reflected. A `false` result means that upload failed (already
  /// logged upstream): the board is still shown, but with a warning that it may
  /// be missing the latest run rather than silently presenting stale data.
  Future<void> cargarRanking({
    required String nivelId,
    required int limite,
    Future<bool>? sincronizacionPendiente,
  }) async {
    _estado = _estado.copyWith(
      nivelId: nivelId,
      status: RankingStatus.cargando,
      mensajeError: null,
      mensajeAdvertencia: null,
    );
    notifyListeners();

    try {
      final sincronizado = await sincronizacionPendiente;
      final dto = await _consulta.obtenerTop(nivelId, limite);
      _estado = _estado.copyWith(
        status: RankingStatus.cargado,
        entradas: dto.entradas,
        mensajeAdvertencia: sincronizado == false
            ? 'Your latest score could not be uploaded, so it may not appear '
                'here yet.'
            : null,
      );
    } catch (e) {
      _estado = _estado.copyWith(
        status: RankingStatus.error,
        entradas: <FilaRanking>[],
        mensajeError: 'Could not load leaderboard.',
      );
    }

    notifyListeners();
  }
}
