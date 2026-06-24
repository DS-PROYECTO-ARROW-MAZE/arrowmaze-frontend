import 'progreso_sync_dto.dart';

/// DTO for the `POST /progress/sync` request envelope.
///
/// Expected shape (matches the backend `SincronizarProgresoRequestDto`; no
/// client-side `estrellas`/score — see [ProgresoSyncDto]):
/// ```json
/// { "progresos": [ { nivelId, movimientos, segundosRestantes, completadoEn } ] }
/// ```
class SyncRequestDto {
  /// Creates a sync request DTO.
  const SyncRequestDto({required this.progresos});

  /// The list of completed runs to upload as a batch.
  final List<ProgresoSyncDto> progresos;

  /// Serializes to the contract JSON shape.
  Map<String, dynamic> toJson() => {
        'progresos': progresos.map((p) => p.toJson()).toList(),
      };
}
