import 'package:flutter/foundation.dart';

import '../../application/ports/consulta_progreso_local.dart';
import '../../application/ports/i_control_audio.dart';
import '../../application/ports/i_registro.dart';
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
    String? nivelIdRemoto,
    ConsultaProgresoLocal? progreso,
    CalcularPuntuacionUseCase? calcularPuntuacion,
    DeshacerMovimientoUseCase? deshacerMovimiento,
    IControlAudio? audioControl,
    SincronizarProgresoUseCase? sincronizar,
    IRegistro? registro,
  })  : _idNivel = idNivel,
        _nivelIdRemoto = nivelIdRemoto,
        _progreso = progreso,
        _sincronizar = sincronizar,
        _registro = registro,
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
      movimientosRestantes: _sesion.presupuestoMovimientos?.restante ?? -1,
      muted: _audioControl?.muted ?? false,
      tiempoRestante: _sesion.tiempoRestante,
      usosUndoRestantes: _deshacerMovimiento.usosRestantes,
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

  /// The backend level UUID, when known — the identity a synced run is keyed by.
  /// `null` for the offline/random board, which simply skips sync.
  final String? _nivelIdRemoto;

  /// Optional local progression store; when present, a victory records the
  /// level as completed with its star count so the next level unlocks.
  final ConsultaProgresoLocal? _progreso;

  final SincronizarProgresoUseCase? _sincronizar;

  /// Optional logging sink; failures of the background sync are reported here
  /// instead of being swallowed.
  final IRegistro? _registro;

  /// The in-flight upload of the just-won run (`POST /progress/sync`), or `null`
  /// when nothing is syncing (no victory yet, or an offline/random board with no
  /// backend level to attribute the run to).
  ///
  /// The leaderboard awaits this before it fetches, so the read never races the
  /// write and the score just earned is reflected. It completes with `true` when
  /// the run uploaded (or there was nothing to send) and `false` when the upload
  /// failed — failures are also logged through [_registro].
  Future<bool>? _sincronizacionEnCurso;

  /// The in-flight victory sync the leaderboard should await before fetching, or
  /// `null` when there is nothing to wait on.
  Future<bool>? get sincronizacionEnCurso => _sincronizacionEnCurso;

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
      if (_definicionNivel.esBonus) {
        victoriaState = VictoriaViewState(
          movimientos: resultado.movimientos,
          puntaje: 0,
          estrellas: 0,
          mostrarPuntuacion: false,
        );
      } else {
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
        _progreso?.registrarCompletado(
          idNivel: _idNivel,
          estrellas: puntuacion.estrellas,
        );
        final idRemoto = _nivelIdRemoto;
        if (idRemoto != null) {
          final run = RunCompletado(
            nivelId: idRemoto,
            movimientos: resultado.movimientos,
            segundosRestantes: _sesion.tiempoRestante?.inSeconds,
            completadoEn: DateTime.now(),
          );
          _encolarYFlushear(run);
        }
      }
    }

    final derrota = _sesion.estado is EstadoDerrota;
    final derrotaPorTiempo = derrota &&
        _definicionNivel.esCronometrado &&
        (_sesion.tiempoRestante == null ||
            _sesion.tiempoRestante == Duration.zero);

    // On a valid exit emit the transient snake-gait descriptor built from the
    // path that just left (carried on the move's delta). It rides on this one
    // state and is cleared on the next — the domain already removed the arrow,
    // so this is purely how the View draws that removal over time (AC1/AC3).
    final trayectoriaSalida = resultado.delta?.trayectoria;
    final animacionSalida = trayectoriaSalida == null
        ? null
        : AnimacionSalida(
            idFlecha: trayectoriaSalida.id,
            segmentos: List<Posicion>.unmodifiable(trayectoriaSalida.segmentos),
            direccionSalida: trayectoriaSalida.direccionCabeza,
            objetivoBorde: _objetivoBorde(
              trayectoriaSalida.cabeza,
              trayectoriaSalida.direccionCabeza,
            ),
          );

    _estado = _estado.copyWith(
      tablero: invalido ? null : _instantanea(),
      movimientos: resultado.movimientos,
      movimientosRestantes: _sesion.presupuestoMovimientos?.restante ?? -1,
      coleccionables: _coleccionables,
      movimientoInvalido: invalido,
      victoria: victoriaState,
      derrota: derrota,
      derrotaPorTiempo: derrotaPorTiempo,
      tiempoRestante: _sesion.tiempoRestante,
      animacionSalida: animacionSalida,
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
      movimientosRestantes: _sesion.presupuestoMovimientos?.restante ?? -1,
      movimientoInvalido: false,
      usosUndoRestantes: _deshacerMovimiento.usosRestantes,
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
    if (!_definicionNivel.esCronometrado || _sesion.estaTerminada) return;
    _reloj.detener();
    _reloj.iniciar(const Duration(seconds: 1), _tic);
  }

  /// One clock tick: advances the session by a second and publishes the new
  /// remaining time, surfacing the defeat transition when it lands.
  void _tic() {
    _sesion.avanzarTiempo(const Duration(seconds: 1));
    if (_sesion.estaTerminada) _reloj.detener();
    final derrota = _sesion.estado is EstadoDerrota;
    _estado = _estado.copyWith(
      derrota: derrota,
      derrotaPorTiempo: derrota,
      movimientosRestantes: _sesion.presupuestoMovimientos?.restante ?? -1,
      tiempoRestante: _sesion.tiempoRestante,
    );
    notifyListeners();
  }

  /// Enqueues [run] and starts its upload, keeping the in-flight future in
  /// [_sincronizacionEnCurso] so the leaderboard can await it before fetching.
  ///
  /// The victory overlay is shown without waiting on this — the upload runs in
  /// the background — but the future is retained (instead of fire-and-forget) so
  /// the leaderboard read can confirm the write resolved (no read-before-write
  /// race) and so a failed upload is surfaced rather than swallowed.
  void _encolarYFlushear(RunCompletado run) {
    final sincronizar = _sincronizar;
    if (sincronizar == null) return;
    _sincronizacionEnCurso = _subirRun(sincronizar, run);
  }

  /// Uploads [run] and reports whether it succeeded, logging any failure so a
  /// rejected sync (an expired token → 401, a malformed batch → 400, or a
  /// dropped connection) is never silently lost.
  Future<bool> _subirRun(
    SincronizarProgresoUseCase sincronizar,
    RunCompletado run,
  ) async {
    try {
      await sincronizar.encolar(run);
      final resultado = await sincronizar.sincronizar();
      if (!resultado.exitoso) {
        _registro?.error(
          'Progress sync failed for level $_nivelIdRemoto: '
          '${resultado.mensajeError}',
        );
      }
      return resultado.exitoso;
    } catch (e) {
      _registro?.error('Progress sync threw for level $_nivelIdRemoto: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _moverFlecha.publicador.desuscribir(this);
    _reloj.detener();
    super.dispose();
  }

  /// The first off-board cell reached by stepping from [cabeza] along
  /// [direccion] — the target the exiting head travels to so the whole body
  /// clears the board. Walks cell by cell until it lands outside the grid.
  Posicion _objetivoBorde(Posicion cabeza, Direccion direccion) {
    var actual = cabeza;
    while (_dentroDelTablero(actual)) {
      actual = actual.desplazar(direccion);
    }
    return actual;
  }

  /// Whether [posicion] lies within the board's row/column bounds.
  bool _dentroDelTablero(Posicion posicion) =>
      posicion.fila >= 0 &&
      posicion.columna >= 0 &&
      posicion.fila < _tablero.filas &&
      posicion.columna < _tablero.columnas;

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
      CeldaAusente() => CeldaUI(posicion: posicion, tipo: TipoCeldaUI.ausente),
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
