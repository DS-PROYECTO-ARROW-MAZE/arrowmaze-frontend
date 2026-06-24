import '../../domain/progreso/i_cola_sincronizacion.dart';
import '../ports/consulta_progreso_local.dart';

/// Wipes every trace of the current user's device-local play state.
///
/// Two stores hold per-user data on the device: the persisted progression
/// ([ConsultaProgresoLocal] — completed levels and stars, the unlock source of
/// truth) and the in-memory upload queue ([IColaSincronizacion] — runs awaiting
/// `POST /progress/sync`). Both must be cleared on logout and on a fresh
/// login/register so one account's progress never leaks into another's
/// (account-switch state leakage). Progression is device-local with no
/// server-side read path, so clearing is the only guarantee of a clean slate.
class LimpiarProgresoLocalUseCase {
  /// Creates the use case over the two device-local stores.
  const LimpiarProgresoLocalUseCase({
    required ConsultaProgresoLocal progreso,
    required IColaSincronizacion cola,
  })  : _progreso = progreso,
        _cola = cola;

  final ConsultaProgresoLocal _progreso;
  final IColaSincronizacion _cola;

  /// Clears persisted progression and the pending-sync queue.
  Future<void> ejecutar() async {
    await _progreso.limpiar();
    await _cola.vaciar();
  }
}
