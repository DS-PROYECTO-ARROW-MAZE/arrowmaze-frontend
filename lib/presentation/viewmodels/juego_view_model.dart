import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/ports/consulta_progreso_local.dart';
import '../../application/ports/i_control_audio.dart';
import '../../application/ports/reloj.dart';
import '../../application/use_cases/calcular_puntuacion_use_case.dart';
import '../../application/use_cases/deshacer_movimiento_use_case.dart';
import '../../application/use_cases/sincronizar_progreso_use_case.dart';
import '../../domain/evento_juego.dart';
import '../../domain/observador_juego.dart';
import '../../application/use_cases/mover_flecha_use_case.dart';
import '../../domain/entities/celda.dart';
import '../../domain/progreso/run_completado.dart';
import '../../domain/puntuacion/definicion_nivel.dart';
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
/// on infrastructure. As a `ChangeNotifier` it plays the **MVVM data-binding**
/// Observer role between View and ViewModel (distinct from the game-event
/// Observer of ticket 07).
///
/// As an [ObservadorJuego] it also plays the **game-event** Observer role:
/// it subscribes to `moverFlecha.publicador` in the constructor, accumulates
/// incremental state from events in [alOcurrirEvento], and calls
/// `notifyListeners()` only at the end of [tocar] — keeping the two Observer
/// roles strictly separated.
///
/// Taps are routed through the use case, which in turn runs them through the
/// [SesionJuego]'s GoF State (DM-F5). This view model then **maps** that domain
/// session state onto UI snapshots — a [VictoriaViewState], the paused/defeat
/// flags and the HUD clock — keeping the domain `EstadoSesion` out of the View
/// entirely. On a timed level it drives a one-second [Reloj] tick that advances the
/// session clock and surfaces the defeat transition.
///
/// On victory the [CalcularPuntuacionUseCase] computes the score and star rating
/// from the level's [DefinicionNivel] tuning data (ticket 06).
class JuegoViewModel extends ChangeNotifier implements ObservadorJuego {
  /// Injects the board to render, the use case that mutates it, the scoring
  /// definition and use case; the session gating every tap is taken from the
  /// use case so both share one instance.
  JuegoViewModel({
    required this._tablero,
    required MoverFlechaUseCase moverFlecha,
    required this._definicionNivel,
    required this._reloj,
    int idNivel = 1,
    ConsultaProgresoLocal? progreso,
    CalcularPuntuacionUseCase? calcularPuntuacion,
    DeshacerMovimientoUseCase? deshacerMovimiento,
    IControlAudio? audioControl,
    SincronizarProgresoUseCase? sincronizar,
  })  : _idNivel = idNivel,
        _progreso = progreso,
        _sincronizar = sincronizar,
        _moverFlecha = moverFlecha,
        _sesion = moverFlecha.sesion,
        _audioControl = audioControl,
        _calcularPuntuacion = calcularPuntuacion ?? const CalcularPuntuacionUseCase(),
        // Defaults to an undo wired onto the move use case's own session,
        // history and counter, so both share one source of truth.
        _deshacerMovimiento = deshacerMovimiento ??
            DeshacerMovimientoUseCase(
              sesion: moverFlecha.sesion,
              historial: moverFlecha.historial,
              contador: moverFlecha.contador,
            ) {
    _estado = JuegoViewState(
      tablero: _instantanea(),
      movimientos: 0,
      muted: _audioControl?.muted ?? false,
      tiempoRestante: _sesion.tiempoRestante,
    );
    _iniciarReloj();
  }

  final Tablero _tablero;
  final MoverFlechaUseCase _moverFlecha;
  final DeshacerMovimientoUseCase _deshacerMovimiento;
  final SesionJuego _sesion;
  final DefinicionNivel _definicionNivel;
  final CalcularPuntuacionUseCase _calcularPuntuacion;
  final IControlAudio? _audioControl;

  /// The id of the level being played — used to record completion against the
  /// right level for progression/unlocks (Ticket 13).
  final int _idNivel;

  /// Optional local progression store; when present, a victory records the
  /// level as completed with its star count so the next level unlocks.
  final ConsultaProgresoLocal? _progreso;

  final SincronizarProgresoUseCase? _sincronizar;

  final Reloj _reloj;

  int _coleccionables = 0;

  late JuegoViewState _estado;

  /// The current immutable state the View renders.
  JuegoViewState get estado => _estado;

  // ---------------------------------------------------------------------------
  // ObservadorJuego — game-event Observer (GoF, ticket 07)
  // ---------------------------------------------------------------------------

  /// Receives each [EventoJuego] dispatched by the publisher immediately after
  /// the use case produces it. Accumulates incremental HUD data (e.g. the
  /// collectibles counter) so [tocar] can assemble the final state snapshot in
  /// a single [copyWith] call.
  ///
  /// Does **not** call `notifyListeners()` here — that is the MVVM data-binding
  /// channel and belongs exclusively at the end of [tocar] / [_tic].
  @override
  void alOcurrirEvento(EventoJuego evento) {
    if (evento.tipo == TipoEvento.coleccionableRecogido) {
      _coleccionables++;
    }
  }

  // ---------------------------------------------------------------------------
  // MVVM data-binding (ChangeNotifier — View↔ViewModel)
  // ---------------------------------------------------------------------------

  /// Handles a tap on the cell at [posicion].
  ///
  /// Runs the move use case (which publishes events synchronously, triggering
  /// [alOcurrirEvento] before this method continues) and then publishes a new
  /// [JuegoViewState] via [copyWith] for any tap that counts as a move.
  /// A **valid** move rebuilds the board snapshot; a **penalized invalid** move
  /// keeps the existing snapshot untouched and only raises
  /// [JuegoViewState.movimientoInvalido] so the View can play its shake/flash.
  /// A tap that resolves to no arrow — or one rejected while paused or
  /// finished — is ignored (no notification).
  void tocar(Posicion posicion) {
    final resultado = _moverFlecha.ejecutar(posicion);
    // Events were already delivered to alOcurrirEvento via the publisher;
    // _coleccionables is up to date before we reach this line.
    if (!resultado.registrado) return;

    final invalido = !resultado.valido;
    _coleccionables += resultado.eventos
        .where((e) => e.tipo == TipoEvento.coleccionableRecogido)
        .length;
    if (_sesion.estaTerminada) _reloj.detener();

    VictoriaViewState? victoriaState;
    if (_sesion.estado is EstadoVictoria) {
      final segundosRestantes =
          _sesion.tiempoRestante?.inSeconds ?? 0;
      final puntuacion = _calcularPuntuacion.calcular(
        definicion: _definicionNivel,
        movimientos: resultado.movimientos,
        segundosRestantes: segundosRestantes,
      );
      victoriaState = VictoriaViewState(
        movimientos: resultado.movimientos,
        puntaje: puntuacion.puntaje,
        estrellas: puntuacion.estrellas,
      );
      // Record the clear so the next level unlocks (Ticket 13). Fire-and-forget:
      // the local store persists in the background; the UI does not wait on it.
      _progreso?.registrarCompletado(
        idNivel: _idNivel,
        estrellas: puntuacion.estrellas,
      );

      // Enqueue the run for sync and trigger an immediate flush (Ticket 15).
      // Fire-and-forget: the sync pipeline runs in the background.
      final run = RunCompletado(
        nivelId: _idNivel.toString(),
        estrellas: puntuacion.estrellas,
        movimientos: resultado.movimientos,
        segundosRestantes: _sesion.tiempoRestante?.inSeconds,
        completadoEn: DateTime.now(),
      );
      _encolarYFlushear(run);
    }

    _estado = _estado.copyWith(
      tablero: invalido ? null : _instantanea(),
      movimientos: resultado.movimientos,
      coleccionables: _coleccionables,
      movimientoInvalido: invalido,
      victoria: victoriaState,
      derrota: _sesion.estado is EstadoDerrota,
      tiempoRestante: _sesion.tiempoRestante,
    );
    notifyListeners(); // MVVM data-binding: push new state to the View.
  }

  /// Toggles global audio mute on/off.
  void toggleMute() {
    _audioControl?.toggleMute();
    _estado = _estado.copyWith(muted: _audioControl?.muted ?? false);
    notifyListeners();
  }

  /// Whether an undo is available right now — there is a move to reverse and the
  /// session is still in play. The View binds the undo button's enabled state to
  /// this.
  bool get puedeDeshacer => _deshacerMovimiento.puedeDeshacer;

  /// Undoes the last move (valid or invalid), rolling the board and the move
  /// counter back together (ticket 09, B4).
  ///
  /// A valid-move undo restores the arrow, so the board snapshot is rebuilt; an
  /// invalid-move undo only rolls back the counter and leaves the snapshot as is.
  /// Either way the invalid-tap flag is cleared so undoing never triggers the
  /// shake/flash. An undo with nothing to reverse (or in a finished session) is a
  /// silent no-op.
  void deshacer() {
    final resultado = _deshacerMovimiento.ejecutar();
    if (!resultado.registrado) return;

    _estado = _estado.copyWith(
      tablero: resultado.valido ? _instantanea() : null,
      movimientos: resultado.movimientos,
      movimientoInvalido: false,
    );
    notifyListeners(); // MVVM data-binding: push the reversed state to the View.
  }

  /// Pauses the session: taps are rejected and the clock freezes until [reanudar].
  void pausar() {
    _sesion.pausar();
    _reloj.detener();
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
    _reloj.detener();
    _reloj.iniciar(const Duration(seconds: 1), _tic);
  }

  /// One clock tick: advances the session by a second and publishes the new
  /// remaining time, surfacing the defeat transition when it lands.
  void _tic() {
    _sesion.avanzarTiempo(const Duration(seconds: 1));
    if (_sesion.estaTerminada) _reloj.detener();
    _estado = _estado.copyWith(
      derrota: _sesion.estado is EstadoDerrota,
      tiempoRestante: _sesion.tiempoRestante,
    );
    notifyListeners();
  }

  /// Enqueues [run] in the sync queue and triggers an immediate flush.
  void _encolarYFlushear(RunCompletado run) {
    final sincronizar = _sincronizar;
    if (sincronizar == null) return;
    unawaited(sincronizar.encolar(run).then((_) => sincronizar.sincronizar()));
  }

  @override
  void dispose() {
    _moverFlecha.publicador.desuscribir(this);
    _reloj.detener();
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
