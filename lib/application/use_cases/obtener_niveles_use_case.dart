import '../../domain/niveles/regla_desbloqueo.dart';
import '../ports/catalogo_niveles.dart';
import '../ports/consulta_progreso_local.dart';
import 'nivel_con_estado.dart';

/// Use case: list every level joined with the player's progression state
/// (Ticket 13, DM §10.3).
///
/// Joins the [CatalogoNiveles] catalog with the completed-set from
/// [ConsultaProgresoLocal], applying [ReglaDesbloqueo] to decide which levels
/// are playable. The lock policy is injected, so the View never computes locks
/// (SRP) and the rule can change without touching this use case (OCP).
class ObtenerNivelesUseCase {
  /// Creates the use case with the catalog, local progress, and unlock rule.
  ObtenerNivelesUseCase({
    required CatalogoNiveles catalogo,
    required ConsultaProgresoLocal progreso,
    ReglaDesbloqueo regla = const ReglaDesbloqueoSecuencial(),
  })  : _catalogo = catalogo,
        _progreso = progreso,
        _regla = regla;

  final CatalogoNiveles _catalogo;
  final ConsultaProgresoLocal _progreso;
  final ReglaDesbloqueo _regla;

  /// Returns the ordered levels, each decorated with lock + completion + stars.
  Future<List<NivelConEstado>> ejecutar() async {
    final niveles = await _catalogo.listar();
    final completados = await _progreso.nivelesCompletados();
    final desbloqueoEfectivo = _conjuntoDesbloqueoEfectivo(completados);

    final resultado = <NivelConEstado>[];
    for (final resumen in niveles) {
      // Completion + stars come from the *real* records: a gap level shows as
      // unlocked-but-not-cleared, never a phantom star (Ticket 32, AC1).
      final completado = completados.contains(resumen.id);
      resultado.add(
        NivelConEstado(
          resumen: resumen,
          desbloqueado:
              _regla.estaDesbloqueado(resumen.id, desbloqueoEfectivo),
          completado: completado,
          estrellas: completado ? await _progreso.mejorEstrellas(resumen.id) : 0,
        ),
      );
    }
    return resultado;
  }

  /// The completed-set the unlock rule reads, saturated up to the highest
  /// cleared level (Ticket 32, AC2).
  ///
  /// Sequential progression cannot skip levels: clearing level *H* implies every
  /// level `1..H` was cleared. So if the stored set arrives with a hole (a lossy
  /// login restore, an unsynced clear, a namespace switch), we fill `1..max` and
  /// feed *that* to [ReglaDesbloqueo]. This keeps the injected rule the sole
  /// lock decision-maker (OCP) while guaranteeing the monotonic-unlock
  /// invariant — an unlocked level always implies every earlier level unlocked —
  /// so no padlock is ever rendered before a level the player has reached.
  Set<int> _conjuntoDesbloqueoEfectivo(Set<int> completados) {
    if (completados.isEmpty) return completados;
    final maximo = completados.reduce((a, b) => a > b ? a : b);
    return {for (var id = 1; id <= maximo; id++) id};
  }
}
