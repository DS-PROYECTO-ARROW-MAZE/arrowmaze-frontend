/// DTO for a single run in the batch sync request (Pact consumer contract, AC3).
class SyncRunDto {
  /// Creates a sync run DTO.
  const SyncRunDto({
    required this.nivelId,
    required this.movimientos,
    required this.segundosRestantes,
    required this.puntaje,
    required this.estrellas,
    required this.completadoEn,
  });

  /// The level that was cleared.
  final int nivelId;

  /// Total registered taps.
  final int movimientos;

  /// Remaining clock seconds when cleared.
  final int segundosRestantes;

  /// Final computed score.
  final int puntaje;

  /// Star rating: 0–3.
  final int estrellas;

  /// ISO-8601 UTC timestamp.
  final String completadoEn;

  /// Serializes to the Pact contract JSON shape.
  Map<String, dynamic> toJson() => {
        'nivelId': nivelId,
        'movimientos': movimientos,
        'segundosRestantes': segundosRestantes,
        'puntaje': puntaje,
        'estrellas': estrellas,
        'completadoEn': completadoEn,
      };
}
