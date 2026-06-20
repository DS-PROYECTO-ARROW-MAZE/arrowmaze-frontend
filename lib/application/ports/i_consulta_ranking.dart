import '../../domain/ranking/ranking_dto.dart';

/// Read-only port for querying the leaderboard (DM-B5, E3).
///
/// The client only **reads** top scores — no write method exists here.
/// Writes happen server-side via the sync pipeline (ticket 10).
abstract interface class IConsultaRanking {
  /// Returns the top [limite] scores for level [idNivel].
  Future<RankingDto> obtenerTop(int idNivel, int limite);
}
