import 'fila_ranking.dart';

/// The read-only projection returned by [IConsultaRanking.obtenerTop] (DM-B5, E3).
///
/// Carries the top-N rows for a given `(idNivel, limite)` request.
/// Immutable, no Flutter dependency — lives in the domain layer.
class RankingDto {
  /// Creates a ranking DTO.
  const RankingDto({required this.filas});

  /// The ordered list of ranking rows (position 1 = best score).
  final List<FilaRanking> filas;
}
