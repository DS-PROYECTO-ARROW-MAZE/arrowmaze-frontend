import '../../domain/progreso/i_cola_sincronizacion.dart';
import '../../domain/progreso/run_completado.dart';
import '../ports/i_repositorio_progreso.dart';

/// The result of a sync attempt (DM-B3, E2).
class ResultadoSincronizacion {
  /// Creates a sync result.
  const ResultadoSincronizacion({required this.exitoso, this.mensajeError});

  /// Whether the batch upload succeeded.
  final bool exitoso;

  /// A user-facing error message, or `null` on success.
  final String? mensajeError;
}

/// Queues completed runs offline and uploads them as a single batch
/// when the user synchronises (AC1, AC2, AC4).
///
/// Depends only on ports ([IColaSincronizacion], [IRepositorioProgreso]) —
/// never on infrastructure. On a failed upload the queue is kept intact
/// so the user can retry without data loss.
class SincronizarProgresoUseCase {
  /// Creates the sync use case with injected ports.
  const SincronizarProgresoUseCase({
    required IColaSincronizacion cola,
    required IRepositorioProgreso repositorio,
  })  : _cola = cola,
        _repositorio = repositorio;

  final IColaSincronizacion _cola;
  final IRepositorioProgreso _repositorio;

  /// Appends [run] to the offline queue (AC1).
  Future<void> encolar(RunCompletado run) => _cola.encolar(run);

  /// Returns the number of pending runs in the queue.
  Future<int> pendientes() => _cola.cantidadPendientes();

  /// Uploads all pending runs as a single batch (AC2).
  ///
  /// On success the queue is cleared. On failure the queue stays intact (AC4).
  Future<ResultadoSincronizacion> sincronizar() async {
    final pendientes = await _cola.obtenerPendientes();

    if (pendientes.isEmpty) {
      return const ResultadoSincronizacion(exitoso: true);
    }

    final exito = await _repositorio.guardarLote(pendientes);

    if (exito) {
      await _cola.vaciar();
      return const ResultadoSincronizacion(exitoso: true);
    }

    return const ResultadoSincronizacion(
      exitoso: false,
      mensajeError: 'No se pudo sincronizar. Intenta de nuevo.',
    );
  }
}
