import 'package:flutter/foundation.dart';

import '../../application/use_cases/nivel_con_estado.dart';
import '../../application/use_cases/obtener_niveles_use_case.dart';
import 'seleccion_niveles_view_state.dart';

/// The Level Selection screen's only collaborator (Ticket 13, DM §10.4).
///
/// Calls [ObtenerNivelesUseCase] (which joins catalog + progression + unlock
/// rule) and publishes [SeleccionNivelesViewState] snapshots. The View never
/// computes locks and never touches a port directly (MVVM). Replaces the
/// use-case bypass of the ticket-05 `SeleccionNivelViewModel`, which is left
/// untouched.
class SeleccionNivelesViewModel extends ChangeNotifier {
  /// Creates the ViewModel with the injected progression use case.
  SeleccionNivelesViewModel({required ObtenerNivelesUseCase obtenerNiveles})
      : _obtenerNiveles = obtenerNiveles;

  final ObtenerNivelesUseCase _obtenerNiveles;

  SeleccionNivelesViewState _estado = const SeleccionNivelesViewState();

  /// The current immutable state the View renders.
  SeleccionNivelesViewState get estado => _estado;

  /// Loads (or reloads) the level catalog with its progression state.
  Future<void> cargar() async {
    _estado = _estado.copyWith(cargando: true, mensajeError: null);
    notifyListeners();

    try {
      final niveles = await _obtenerNiveles.ejecutar();
      _estado = _estado.copyWith(
        cargando: false,
        niveles: niveles.map(_mapear).toList(),
      );
    } catch (_) {
      _estado = _estado.copyWith(
        cargando: false,
        niveles: const [],
        mensajeError: 'Could not load levels.',
      );
    }
    notifyListeners();
  }

  NivelResumenUI _mapear(NivelConEstado nivel) {
    return NivelResumenUI(
      id: nivel.resumen.id,
      idRemoto: nivel.resumen.idRemoto,
      nombre: nivel.resumen.nombre,
      dificultad: nivel.resumen.dificultad,
      desbloqueado: nivel.desbloqueado,
      completado: nivel.completado,
      estrellas: nivel.estrellas,
    );
  }
}
