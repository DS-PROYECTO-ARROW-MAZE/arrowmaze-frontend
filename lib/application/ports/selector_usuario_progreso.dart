/// Port for selecting **whose** local progression is active (Ticket 24).
///
/// Local progress is device-persisted and namespaced per user, so switching the
/// active user reveals that account's own unlocks (and hides everyone else's)
/// without wiping anything. Login/register set the active user; each account's
/// progress then survives logout and re-login on the same device.
///
/// Kept separate from [ConsultaProgresoLocal] (the read/write port used by the
/// game and Level Selection) so only the auth flow depends on this capability.
abstract interface class SelectorUsuarioProgreso {
  /// Makes [usuario] the active account for all subsequent local progress
  /// reads and writes. Idempotent; the choice is persisted across restarts.
  Future<void> establecerUsuario(String usuario);
}
