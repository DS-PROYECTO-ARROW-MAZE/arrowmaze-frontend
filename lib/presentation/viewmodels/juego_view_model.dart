import 'package:flutter/foundation.dart';

import '../../application/use_cases/mover_flecha_use_case.dart';
import '../../domain/entities/celda.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/direccion.dart';
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
  /// Runs the move use case and publishes a new [JuegoViewState] via [copyWith]
  /// for any tap that counts as a move. A **valid** move rebuilds the board
  /// snapshot; a **penalized invalid** move keeps the existing snapshot untouched
  /// and only raises [JuegoViewState.movimientoInvalido] so the View can play its
  /// shake/flash. A tap that resolves to no arrow is ignored (no notification).
  void tocar(Posicion posicion) {
    final resultado = _moverFlecha.ejecutar(posicion);
    if (!resultado.registrado) return;

    final invalido = !resultado.valido;
    _estado = _estado.copyWith(
      // Rebuild the snapshot only when the board actually changed; an invalid
      // move must leave the very same TableroUI instance in place.
      tablero: invalido ? null : _instantanea(),
      movimientos: resultado.movimientos,
      movimientoInvalido: invalido,
    );
    notifyListeners();
  }

  /// Reads the current board through the port into a flat UI snapshot.
  TableroUI _instantanea() {
    final celdas = <CeldaUI>[];
    for (var fila = 0; fila < _tablero.filas; fila++) {
      for (var columna = 0; columna < _tablero.columnas; columna++) {
        final posicion = Posicion.en(fila: fila, columna: columna);
        celdas.add(_aCeldaUI(posicion, _tablero.celdaEn(posicion)));
      }
    }
    return TableroUI(
      filas: _tablero.filas,
      columnas: _tablero.columnas,
      celdas: celdas,
    );
  }

  /// Maps a domain [Celda] to its theme-free UI snapshot, enriching arrow
  /// segments with the path geometry the painter needs (connections, head).
  CeldaUI _aCeldaUI(Posicion posicion, Celda celda) {
    return switch (celda) {
      CeldaFlecha(:final idFlecha) => _segmentoUI(posicion, idFlecha),
      CeldaPared() => CeldaUI(posicion: posicion, tipo: TipoCeldaUI.pared),
      CeldaVacia() => CeldaUI(posicion: posicion, tipo: TipoCeldaUI.vacia),
    };
  }

  /// Builds the render model for an arrow segment at [posicion], reading its
  /// path's bend geometry through the [Tablero] port.
  CeldaUI _segmentoUI(Posicion posicion, int idFlecha) {
    final trayectoria = _tablero.trayectoriaEn(posicion);
    final esCabeza = trayectoria?.esCabeza(posicion) ?? false;
    return CeldaUI(
      posicion: posicion,
      tipo: TipoCeldaUI.flecha,
      idFlecha: idFlecha,
      conexiones: trayectoria?.conexionesEn(posicion) ?? const <Direccion>{},
      esCabeza: esCabeza,
      direccion: esCabeza ? trayectoria?.direccionCabeza : null,
    );
  }
}
