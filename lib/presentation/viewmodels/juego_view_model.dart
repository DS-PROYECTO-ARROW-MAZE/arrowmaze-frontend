import 'package:flutter/foundation.dart';

import '../../application/use_cases/mover_flecha_use_case.dart';
import '../../domain/entities/celda.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'juego_view_state.dart';

/// The View's only collaborator: it owns the [JuegoViewState], turns taps into
/// use-case calls, and notifies the View when a new state is published.
///
/// It depends on the [Tablero] port and [MoverFlechaUseCase] (injected) — never
/// on infrastructure. As a `ChangeNotifier` it plays the data-binding Observer
/// role between View and ViewModel (distinct from the game-event Observer of
/// ticket 07).
class JuegoViewModel extends ChangeNotifier {
  /// Injects the board to render and the use case that mutates it.
  JuegoViewModel({
    required Tablero tablero,
    required MoverFlechaUseCase moverFlecha,
  })  : _tablero = tablero,
        _moverFlecha = moverFlecha {
    _estado = JuegoViewState(
      tablero: _instantanea(),
      movimientos: 0,
    );
  }

  final Tablero _tablero;
  final MoverFlechaUseCase _moverFlecha;

  late JuegoViewState _estado;

  /// The current immutable state the View renders.
  JuegoViewState get estado => _estado;

  /// Handles a tap on the cell at [posicion].
  ///
  /// Runs the move use case, rebuilds the board snapshot, and publishes a new
  /// [JuegoViewState] via [copyWith] only when something actually changed.
  void tocar(Posicion posicion) {
    final resultado = _moverFlecha.ejecutar(posicion);
    if (!resultado.valido) return;

    _estado = _estado.copyWith(
      tablero: _instantanea(),
      movimientos: resultado.movimientos,
    );
    notifyListeners();
  }

  /// Reads the current board through the port into a flat UI snapshot.
  TableroUI _instantanea() {
    final celdas = <CeldaUI>[];
    for (var fila = 0; fila < _tablero.filas; fila++) {
      for (var columna = 0; columna < _tablero.columnas; columna++) {
        final posicion = Posicion.en(fila: fila, columna: columna);
        celdas.add(_aCeldaUI(_tablero.celdaEn(posicion)));
      }
    }
    return TableroUI(
      filas: _tablero.filas,
      columnas: _tablero.columnas,
      celdas: celdas,
    );
  }

  /// Maps a domain [Celda] to its theme-free UI snapshot.
  CeldaUI _aCeldaUI(Celda celda) {
    return switch (celda) {
      CeldaFlecha(:final posicion, :final direccion) => CeldaUI(
          posicion: posicion,
          tipo: TipoCeldaUI.flecha,
          direccion: direccion,
        ),
      CeldaPared(:final posicion) =>
        CeldaUI(posicion: posicion, tipo: TipoCeldaUI.pared),
      CeldaVacia(:final posicion) =>
        CeldaUI(posicion: posicion, tipo: TipoCeldaUI.vacia),
    };
  }
}
