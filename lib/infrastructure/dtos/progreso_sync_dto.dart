/// DTO for a single item in the `POST /progress/sync` batch.
///
/// Mirrors the backend `ProgresoEntradaRequestDto` exactly: `nivelId`,
/// `movimientos`, optional `segundosRestantes`, `completadoEn`. The backend runs
/// with `forbidNonWhitelisted: true` (Ticket 19 / ADR-0005), so any extra field
/// — notably a client-computed `estrellas` — would make the whole request fail
/// with `400 Bad Request`. The server recomputes stars/score itself, so none is
/// sent.
class ProgresoSyncDto {
  /// Creates a progress sync item DTO.
  const ProgresoSyncDto({
    required this.nivelId,
    required this.movimientos,
    this.segundosRestantes,
    required this.completadoEn,
  });

  /// The level that was cleared (server UUID).
  final String nivelId;

  /// Total registered taps.
  final int movimientos;

  /// Remaining clock seconds when cleared, or `null` for untimed levels.
  final int? segundosRestantes;

  /// ISO-8601 timestamp.
  final String completadoEn;

  /// Serializes to the contract JSON shape.
  Map<String, dynamic> toJson() => {
        'nivelId': nivelId,
        'movimientos': movimientos,
        'segundosRestantes': segundosRestantes,
        'completadoEn': completadoEn,
      };
}
