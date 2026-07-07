import '../../domain/progreso/i_cola_sincronizacion.dart';
import '../ports/selector_usuario_progreso.dart';

/// Makes a signed-in account's device-local progression active (Ticket 24).
///
/// On login/register this switches the local progress namespace to [usuario]
/// (via [SelectorUsuarioProgreso]) so that account's own unlocks are shown, and
/// empties the in-memory upload queue so a previous session's pending runs never
/// sync under the new account. It **does not** wipe progression — each user's
/// progress is retained on the device and reappears when they log back in.
class ActivarProgresoUsuarioUseCase {
  /// Creates the use case over the active-user selector and the upload queue.
  const ActivarProgresoUsuarioUseCase({
    required SelectorUsuarioProgreso selector,
    required IColaSincronizacion cola,
  })  : _selector = selector,
        _cola = cola;

  final SelectorUsuarioProgreso _selector;
  final IColaSincronizacion _cola;

  /// Activates [usuario]'s local progression and clears the pending-sync queue.
  Future<void> ejecutar(String usuario) async {
    await _selector.establecerUsuario(usuario);
    await _cola.vaciar();
  }
}
