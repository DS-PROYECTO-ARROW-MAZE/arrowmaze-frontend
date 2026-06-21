/// The progression unlock policy (Ticket 13, DM §10.3).
///
/// Encapsulated as a Strategy so the rule can change (e.g. star-gated unlocks)
/// without touching [ObtenerNivelesUseCase] or any View (OCP). The default is
/// [ReglaDesbloqueoSecuencial].
abstract interface class ReglaDesbloqueo {
  /// Whether [idNivel] is playable given the set of [completados] level ids.
  bool estaDesbloqueado(int idNivel, Set<int> completados);
}

/// Sequential progression: level 1 is always open; level *N* unlocks once level
/// *N − 1* has been completed.
class ReglaDesbloqueoSecuencial implements ReglaDesbloqueo {
  /// Creates the sequential unlock rule.
  const ReglaDesbloqueoSecuencial();

  /// The id of the first level, which is always unlocked.
  static const int primerNivel = 1;

  @override
  bool estaDesbloqueado(int idNivel, Set<int> completados) {
    if (idNivel <= primerNivel) return true;
    return completados.contains(idNivel - 1);
  }
}
