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

    final resultado = <NivelConEstado>[];
    for (final resumen in niveles) {
      final completado = completados.contains(resumen.id);
      resultado.add(
        NivelConEstado(
          resumen: resumen,
          desbloqueado: _regla.estaDesbloqueado(resumen.id, completados),
          completado: completado,
          estrellas: completado ? await _progreso.mejorEstrellas(resumen.id) : 0,
        ),
      );
    }
    return resultado;
  }
}
