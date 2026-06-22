/// DTO for a single item in the `POST /progress/sync` batch.
///
/// Mirrors the backend `progresos[]` contract item.
class ProgresoSyncDto {
  /// Creates a progress sync item DTO.
  const ProgresoSyncDto({
    required this.nivelId,
    required this.estrellas,
    required this.movimientos,
    this.segundosRestantes,
    required this.completadoEn,
  });

  /// The level that was cleared (server UUID).
  final String nivelId;

  /// Star rating: 0–3.
  final int estrellas;

  /// Total registered taps.
  final int movimientos;

  /// Remaining clock seconds when cleared, or `null` for untimed levels.
  final int? segundosRestantes;

  /// ISO-8601 timestamp.
  final String completadoEn;

  /// Serializes to the contract JSON shape.
  Map<String, dynamic> toJson() => {
        'nivelId': nivelId,
        'estrellas': estrellas,
        'movimientos': movimientos,
        'segundosRestantes': segundosRestantes,
        'completadoEn': completadoEn,
      };
}
