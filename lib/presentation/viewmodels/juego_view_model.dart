import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/use_cases/evento_juego.dart';
import '../../application/use_cases/mover_flecha_use_case.dart';
import '../../domain/entities/celda.dart';
import '../../domain/sesion/estado_sesion.dart';
import '../../domain/sesion/sesion_juego.dart';
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
///
/// Taps are routed through the use case, which in turn runs them through the
/// [SesionJuego]'s GoF State (DM-F5). This view model then **maps** that domain
/// session state onto UI snapshots — a [VictoriaViewState], the paused/defeat
/// flags and the HUD clock — keeping the domain `EstadoSesion` out of the View
/// entirely. On a timed level it drives a one-second [Timer] that advances the
/// session clock and surfaces the defeat transition.
class JuegoViewModel extends ChangeNotifier {
  /// Injects the board to render and the use case that mutates it; the session
  /// gating every tap is taken from the use case so both share one instance.
  JuegoViewModel({
    required Tablero tablero,
    required MoverFlechaUseCase moverFlecha,
  })  : _tablero = tablero,
        _moverFlecha = moverFlecha,
        _sesion = moverFlecha.sesion {
    _estado = JuegoViewState(
      tablero: _instantanea(),
      movimientos: 0,
      tiempoRestante: _sesion.tiempoRestante,
    );
    _iniciarReloj();
  }

  final Tablero _tablero;
  final MoverFlechaUseCase _moverFlecha;
  final SesionJuego _sesion;

  Timer? _reloj;

  int _coleccionables = 0;

  late JuegoViewState _estado;

  /// The current immutable state the View renders.
  JuegoViewState get estado => _estado;

  /// Handles a tap on the cell at [posicion].
  ///
  /// Runs the move use case and publishes a new [JuegoViewState] via [copyWith]
  /// for any tap that counts as a move. A **valid** move rebuilds the board
  /// snapshot; a **penalized invalid** move keeps the existing snapshot untouched
  /// and only raises [JuegoViewState.movimientoInvalido] so the View can play its
  /// shake/flash. A tap that resolves to no arrow — or one rejected while paused
  /// or finished — is ignored (no notification).
  void tocar(Posicion posicion) {
    final resultado = _moverFlecha.ejecutar(posicion);
    if (!resultado.registrado) return;

    final invalido = !resultado.valido;
    _coleccionables += resultado.eventos
        .where((e) => e.tipo == TipoEvento.coleccionableRecogido)
        .length;
    if (_sesion.estaTerminada) _reloj?.cancel();
    _estado = _estado.copyWith(
      // Rebuild the snapshot only when the board actually changed; an invalid
      // move must leave the very same TableroUI instance in place.
      tablero: invalido ? null : _instantanea(),
      movimientos: resultado.movimientos,
      coleccionables: _coleccionables,
      movimientoInvalido: invalido,
      victoria: _sesion.estado is EstadoVictoria
          ? VictoriaViewState(movimientos: resultado.movimientos)
          : null,
      derrota: _sesion.estado is EstadoDerrota,
      tiempoRestante: _sesion.tiempoRestante,
    );
    notifyListeners();
  }

  /// Pauses the session: taps are rejected and the clock freezes until [reanudar].
  void pausar() {
    _sesion.pausar();
    _reloj?.cancel();
    _estado = _estado.copyWith(pausado: _sesion.estado is EstadoPausado);
    notifyListeners();
  }

  /// Resumes a paused session, returning to play and re-arming the clock.
  void reanudar() {
    _sesion.reanudar();
    _iniciarReloj();
    _estado = _estado.copyWith(pausado: _sesion.estado is EstadoPausado);
    notifyListeners();
  }

  /// Starts the one-second tick that advances a timed level's clock; a no-op on
  /// an untimed level or once the session is finished.
  void _iniciarReloj() {
    if (!_sesion.esCronometrado || _sesion.estaTerminada) return;
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
  }

  /// One clock tick: advances the session by a second and publishes the new
  /// remaining time, surfacing the defeat transition when it lands.
  void _tic() {
    _sesion.avanzarTiempo(const Duration(seconds: 1));
    if (_sesion.estaTerminada) _reloj?.cancel();
    _estado = _estado.copyWith(
      derrota: _sesion.estado is EstadoDerrota,
      tiempoRestante: _sesion.tiempoRestante,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
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
      Coleccionable() =>
        CeldaUI(posicion: posicion, tipo: TipoCeldaUI.coleccionable),
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
