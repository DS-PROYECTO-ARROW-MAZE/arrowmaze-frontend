import 'package:flutter/foundation.dart';

import '../../application/ports/consulta_progreso_local.dart';
import '../../application/ports/haptic_feedback_port.dart';
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
import '../../domain/niveles/dificultad.dart';
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
    Dificultad dificultad = Dificultad.facil,
    String? nivelIdRemoto,
    ConsultaProgresoLocal? progreso,
    CalcularPuntuacionUseCase? calcularPuntuacion,
    DeshacerMovimientoUseCase? deshacerMovimiento,
    IControlAudio? audioControl,
    SincronizarProgresoUseCase? sincronizar,
    IRegistro? registro,
    HapticFeedbackPort? haptica,
    DateTime Function()? ahora,
  })  : _idNivel = idNivel,
        _dificultad = dificultad,
        _nivelIdRemoto = nivelIdRemoto,
        _progreso = progreso,
        _sincronizar = sincronizar,
        _registro = registro,
        _haptica = haptica,
        _ahora = ahora ?? DateTime.now,
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
      pistaHabilitadaEnNivel: pistaHabilitadaEnNivel,
      pistaDisponible: _pistaDisponibleAhora,
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

  /// Optional tactile-feedback port; when present, a **new** invalid-alert pulse
  /// buzzes the device (Ticket 28). Kept behind the port so no Flutter/haptic
  /// symbol reaches `domain`/`application` (DIP).
  final HapticFeedbackPort? _haptica;

  /// Injected clock (`DateTime.now` in production) used to debounce the invalid
  /// alert; overridable so the debounce window is testable deterministically.
  final DateTime Function() _ahora;

  /// The debounce window that coalesces a burst of invalid taps into a single
  /// red-alert pulse and a single haptic buzz: an invalid tap within this span
  /// of the previous *pulse* is still counted as a move but raises no new pulse,
  /// so the flash never strobes (Ticket 28, AC1).
  static const Duration ventanaAlertaInvalida = Duration(milliseconds: 400);

  /// The final-countdown threshold: when a timed level's clock first reaches
  /// this much time left, the ViewModel fires the one-shot time warning — a
  /// distinct HUD style plus a `TipoEvento.avisoTiempo` audio cue (ticket 29).
  static const Duration umbralAvisoTiempo = Duration(seconds: 15);

  /// The hint-unlock threshold (ticket 35, Rule B): on a medium/hard level the
  /// hint button unlocks only once the clock reaches this much time left or less
  /// (`segundosRestantes ≤ 25`). It opens *before* the 15 s warning
  /// ([umbralAvisoTiempo]), so the hint appears first, then the final warning.
  static const Duration umbralPista = Duration(seconds: 25);

  /// One-shot guard for the time warning: it fires **once per run** when the
  /// clock first crosses [umbralAvisoTiempo] (AC1) and must not re-fire on later
  /// ticks or across pause/resume (AC5). A retry opens a fresh session and
  /// ViewModel, so this instance field resets naturally per run.
  bool _avisoTiempoEmitido = false;

  /// When the last alert pulse fired, or `null` when the current streak of
  /// invalid taps has been broken (by a valid move or an undo).
  DateTime? _ultimaAlertaInvalida;

  /// The once-per-level hint guard (ticket 35): latches to `true` the moment a
  /// hint is actually delivered, so the button can never be used a second time
  /// this run. A retry opens a fresh ViewModel, so it resets naturally per run.
  bool _pistaUsada = false;

  /// The id of the level being played — used to record completion against the
  /// right level for progression/unlocks (Ticket 13).
  final int _idNivel;

  /// The level's difficulty — the **data** behind Rule A of the hint gate
  /// (ticket 35): the hint button exists only on medium/hard levels. Never a
  /// subtype, always this value (CLAUDE.md: difficulty is data).
  final Dificultad _dificultad;

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
  /// keeps the existing snapshot untouched, raises [JuegoViewState.movimientoInvalido]
  /// (the rule mirror) and — on the *leading* tap of a rapid streak — the
  /// debounced [JuegoViewState.alertaInvalida] pulse plus a haptic buzz, so the
  /// View flashes/buzzes exactly once (Ticket 28). A tap that resolves to no
  /// arrow — or one rejected while paused or finished — is ignored (no
  /// notification).
  void tocar(Posicion posicion) {
    final resultado = _moverFlecha.ejecutar(posicion);
    // Events were already delivered to alOcurrirEvento via the publisher;
    // _coleccionables is up to date before we reach this line.
    if (!resultado.registrado) return;

    final invalido = !resultado.valido;
    // Debounced red-alert pulse (AC1): only the leading invalid tap of a streak
    // raises the pulse and buzzes; a valid move ends the streak so the next
    // invalid tap alerts again. Haptics ride the pulse, so they coalesce too.
    final bool alerta;
    if (invalido) {
      alerta = _registrarAlertaInvalida();
      if (alerta) _haptica?.vibrar();
    } else {
      alerta = false;
      _ultimaAlertaInvalida = null;
    }
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
        _sesion.esCronometrado &&
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
      alertaInvalida: alerta,
      victoria: victoriaState,
      derrota: derrota,
      derrotaPorTiempo: derrotaPorTiempo,
      pistaDisponible: _pistaDisponibleEn(_sesion.tiempoRestante),
      tiempoRestante: _sesion.tiempoRestante,
      animacionSalida: animacionSalida,
    );
    notifyListeners(); // MVVM data-binding: push new state to the View.
  }

  /// Decides whether this invalid tap should raise a **new** alert pulse, and
  /// records the pulse time when it does. Returns `false` for an invalid tap that
  /// lands within [ventanaAlertaInvalida] of the previous pulse, so a burst of
  /// rapid invalid taps yields a single clean flash + buzz (Ticket 28, AC1).
  bool _registrarAlertaInvalida() {
    final ahora = _ahora();
    final ultima = _ultimaAlertaInvalida;
    if (ultima != null && ahora.difference(ultima) < ventanaAlertaInvalida) {
      return false;
    }
    _ultimaAlertaInvalida = ahora;
    return true;
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

    // An undo ends the current invalid-tap streak, so a following invalid tap
    // pulses again rather than being debounced against a pre-undo pulse.
    _ultimaAlertaInvalida = null;
    _estado = _estado.copyWith(
      tablero: resultado.valido ? _instantanea() : null,
      movimientos: resultado.movimientos,
      movimientosRestantes: _sesion.presupuestoMovimientos?.restante ?? -1,
      movimientoInvalido: false,
      alertaInvalida: false,
      usosUndoRestantes: _deshacerMovimiento.usosRestantes,
    );
    notifyListeners(); // MVVM data-binding: push the reversed state to the View.
  }

  /// Pauses the session: taps are rejected and the clock freezes until [reanudar].
  void pausar() {
    _sesion.pausar();
    _reloj.detener();
    _estado = _estado.copyWith(
      pausado: _sesion.estado is EstadoPausado,
      // Pausing leaves the playing state, so the hint locks until resumed.
      pistaDisponible: _pistaDisponibleEn(_sesion.tiempoRestante),
    );
    notifyListeners();
  }

  /// Resumes a paused session, returning to play and re-arming the clock.
  void reanudar() {
    _sesion.reanudar();
    _iniciarReloj();
    _estado = _estado.copyWith(
      pausado: _sesion.estado is EstadoPausado,
      // Back in play: re-open the hint if the clock is already in the window.
      pistaDisponible: _pistaDisponibleEn(_sesion.tiempoRestante),
    );
    notifyListeners();
  }

  /// Starts the one-second tick that advances a timed level's clock; a no-op on
  /// an untimed session or once the session is finished.
  ///
  /// Whether the level is timed is owned by the **session** (the composition root
  /// opens it with a `limiteTiempo` only for medium/hard levels), not by the
  /// scoring [DefinicionNivel]. Keying off the session guarantees the clock the
  /// HUD shows (`tiempoRestante`, also session-derived) actually ticks — the two
  /// can never disagree and leave a frozen countdown on screen.
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
    final derrota = _sesion.estado is EstadoDerrota;
    _estado = _estado.copyWith(
      derrota: derrota,
      derrotaPorTiempo: derrota,
      avisoTiempo: _evaluarAvisoTiempo(_sesion.tiempoRestante),
      pistaDisponible: _pistaDisponibleEn(_sesion.tiempoRestante),
      movimientosRestantes: _sesion.presupuestoMovimientos?.restante ?? -1,
      tiempoRestante: _sesion.tiempoRestante,
    );
    notifyListeners();
  }

  /// Decides the HUD warning state for the current [restante] time and fires the
  /// one-shot audio cue the first time the clock crosses [umbralAvisoTiempo].
  ///
  /// The cue is published as a domain [EventoJuego] through the move use case's
  /// publisher, so audio reacts via the Observer ([AudioServiceImp]) and no audio
  /// symbol ever reaches this ViewModel (AC4). Guarded by [_avisoTiempoEmitido]
  /// so it fires exactly once per run (AC1) — subsequent ticks and pause/resume
  /// keep the HUD warning on without re-emitting (AC5). Returns whether the HUD
  /// should show the warning style now (the final 15 s, before time runs out).
  bool _evaluarAvisoTiempo(Duration? restante) {
    if (restante == null) return false;
    final enAviso = restante <= umbralAvisoTiempo && restante > Duration.zero;
    if (enAviso && !_avisoTiempoEmitido) {
      _avisoTiempoEmitido = true;
      _moverFlecha.publicador.publicar(
        const EventoJuego(TipoEvento.avisoTiempo, Posicion.en(fila: 0, columna: 0)),
      );
    }
    return enAviso;
  }

  /// **Rule A** of the hint gate (ticket 35): whether this level offers a hint
  /// button at all — `true` only on medium/hard levels, so an easy level never
  /// builds it. Stable for the whole run (difficulty never changes mid-level).
  bool get pistaHabilitadaEnNivel =>
      _dificultad == Dificultad.medio || _dificultad == Dificultad.dificil;

  /// The full hint gate evaluated for the current remaining time — Rule A AND
  /// the `≤ 25 s` time gate AND the session still playing AND the single hint
  /// not yet spent (ticket 35). Kept as a single pure predicate so the View only
  /// reads the resulting boolean and never re-derives difficulty or the clock.
  bool _pistaDisponibleEn(Duration? restante) {
    if (!pistaHabilitadaEnNivel) return false; // Rule A
    if (_pistaUsada) return false; // once per level
    if (_sesion.estado is! EstadoJugando) return false; // playing only
    if (restante == null) return false; // untimed → time gate never met
    return restante <= umbralPista && restante > Duration.zero; // Rule B
  }

  /// The hint gate for the session's current clock — the value published on each
  /// new state.
  bool get _pistaDisponibleAhora => _pistaDisponibleEn(_sesion.tiempoRestante);

  /// Player intent: ask for a hint (ticket 35). The button stays tappable for the
  /// whole run on a medium/hard level (unless already spent), so this method — not
  /// the View — decides what a tap does:
  ///
  /// * **Already spent or off a hint level, or not in play** → a silent no-op; the
  ///   single hint per level cannot be requested twice.
  /// * **Tapped too early** (Rule A holds but the `≤ 25 s` time gate is still
  ///   shut) → publishes [JuegoViewState.pistaBloqueadaSegundos] with the seconds
  ///   left until unlock, so the View shows a "still locked for X s" notice.
  /// * **Unlocked** → finds a currently-clearable arrow, spends the hint
  ///   ([pistaUsada]) and publishes its head as [JuegoViewState.pistaSugerida] so
  ///   the View spotlights it. If no arrow can be cleared right now the hint is
  ///   *not* spent (nothing useful to suggest), leaving it available to retry.
  void pedirPista() {
    // Never usable off a hint level, once spent, or outside active play.
    if (!pistaHabilitadaEnNivel || _pistaUsada) return;
    if (_sesion.estado is! EstadoJugando) return;

    if (!_pistaDisponibleAhora) {
      // Time-locked: surface how long until it opens so the player learns the
      // rule instead of a dead button (a no-op when it can never open — untimed).
      final faltan = _segundosParaDesbloquear(_sesion.tiempoRestante);
      if (faltan == null) return;
      _estado = _estado.copyWith(pistaBloqueadaSegundos: faltan);
      notifyListeners();
      return;
    }

    final sugerida = _buscarPistaSugerida();
    if (sugerida == null) return;
    _pistaUsada = true;
    _estado = _estado.copyWith(
      pistaSugerida: sugerida,
      pistaUsada: true,
      // Spending the hint shuts the gate for good — refresh the lit-button flag.
      pistaDisponible: false,
    );
    notifyListeners();
  }

  /// Seconds remaining until the hint's time gate opens for [restante] — the gap
  /// between the current clock and [umbralPista] (`≤ 25 s`), or `null` when the
  /// gate is already open or can never open (untimed level). Drives the
  /// "still locked for X s" notice shown on an early tap (ticket 35).
  int? _segundosParaDesbloquear(Duration? restante) {
    if (restante == null) return null; // untimed → never opens
    final faltan = restante.inSeconds - umbralPista.inSeconds;
    return faltan > 0 ? faltan : null;
  }

  /// The head of the first arrow whose exit ray is clear to the board edge — a
  /// move that can be made *right now* — or `null` when no arrow is currently
  /// clearable. Scans in row-major order, testing each arrow once at its head
  /// through the same [Tablero.raycast] the move rule uses, so the suggestion can
  /// never point at a blocked arrow.
  Posicion? _buscarPistaSugerida() {
    for (var fila = 0; fila < _tablero.filas; fila++) {
      for (var columna = 0; columna < _tablero.columnas; columna++) {
        final posicion = Posicion.en(fila: fila, columna: columna);
        final trayectoria = _tablero.trayectoriaEn(posicion);
        if (trayectoria == null || !trayectoria.esCabeza(posicion)) continue;
        final rayo =
            _tablero.raycast(trayectoria.cabeza, trayectoria.direccionCabeza);
        if (rayo.despejadoHastaBorde) return trayectoria.cabeza;
      }
    }
    return null;
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

  /// Whether [posicion] lies within the board's row/column/depth bounds.
  ///
  /// Checking `capa` too (not just `fila`/`columna`) is what makes
  /// [_objetivoBorde] terminate for a depth exit (`adelante`/`atras`): that
  /// direction never changes `fila`/`columna`, so without this a 2D-only
  /// bounds check would walk forever.
  bool _dentroDelTablero(Posicion posicion) =>
      posicion.fila >= 0 &&
      posicion.columna >= 0 &&
      posicion.capa >= 0 &&
      posicion.fila < _tablero.filas &&
      posicion.columna < _tablero.columnas &&
      posicion.capa < _tablero.profundo;

  /// Reads the current board through the port into a flat UI snapshot — every
  /// cell of every depth layer (ticket 36), so the rotatable 3D cube view can
  /// render and hit-test the whole board at once. For a flat 2D board
  /// (`profundo == 1`) this is exactly `filas × columnas` cells, unchanged
  /// from before depth-aware boards existed.
  TableroUI _instantanea() {
    final celdas = <CeldaUI>[];
    for (var fila = 0; fila < _tablero.filas; fila++) {
      for (var columna = 0; columna < _tablero.columnas; columna++) {
        for (var capa = 0; capa < _tablero.profundo; capa++) {
          final posicion = Posicion.en(fila: fila, columna: columna, capa: capa);
          celdas.add(_aCeldaUI(posicion, _tablero.celdaEn(posicion)));
        }
      }
    }
    return TableroUI(
      filas: _tablero.filas,
      columnas: _tablero.columnas,
      profundo: _tablero.profundo,
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
