import 'sync_run_dto.dart';

/// DTO for the batch sync request envelope (Pact consumer contract, AC3).
///
/// Expected shape:
/// ```json
/// { "runs": [ { "nivelId", "movimientos", "segundosRestantes",
///               "puntaje", "estrellas", "completadoEn" } ] }
/// ```
class SyncRequestDto {
  /// Creates a sync request DTO.
  const SyncRequestDto({required this.runs});

  /// The list of completed runs to upload as a batch.
  final List<SyncRunDto> runs;

  /// Serializes to the Pact contract JSON shape.
  Map<String, dynamic> toJson() => {
        'runs': runs.map((r) => r.toJson()).toList(),
      };
}
