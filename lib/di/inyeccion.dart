import '../application/decoradores/caso_de_uso_accion.dart';
import '../application/ports/preferencias_usuario.dart';
import '../application/decoradores/decorador_metricas_caso_de_uso.dart';
import '../application/decoradores/decorador_registro_caso_de_uso.dart';
import '../application/decoradores/decorador_seguridad_caso_de_uso.dart';
import '../application/generadores/configuracion_generacion.dart';
import '../application/generadores/generacion_aleatoria_nivel.dart';
import '../application/generadores/generacion_por_archivo_nivel.dart';
import '../application/generadores/generador_nivel_base.dart';
import '../application/ports/cargador_nivel.dart';
import '../application/ports/catalogo_niveles.dart';
import '../application/ports/consulta_progreso_local.dart';
import '../application/ports/fuente_autenticacion.dart';
import '../application/ports/i_caso_de_uso.dart';
import '../application/ports/i_consulta_progreso_remoto.dart';
import '../application/ports/i_consulta_ranking.dart';
import '../application/ports/i_medidor_metricas.dart';
import '../application/ports/i_registro.dart';
import '../application/ports/i_repositorio_progreso.dart';
import '../application/ports/proveedor_sesion.dart';
import '../application/ports/fuente_niveles.dart';
import '../application/ports/selector_usuario_progreso.dart';
import '../application/use_cases/activar_progreso_usuario_use_case.dart';
import '../application/use_cases/cerrar_sesion_use_case.dart';
import '../application/use_cases/consultar_ranking_use_case.dart';
import '../application/use_cases/crear_nivel_use_case.dart';
import '../application/use_cases/iniciar_sesion_use_case.dart';
import '../application/use_cases/mover_flecha_use_case.dart';
import '../application/use_cases/obtener_niveles_use_case.dart';
import '../application/use_cases/obtener_perfil_use_case.dart';
import '../application/use_cases/registrar_usuario_use_case.dart';
import '../application/use_cases/restaurar_progreso_use_case.dart';
import '../application/use_cases/sincronizar_progreso_use_case.dart';
import '../domain/entities/celda.dart';
import '../domain/entities/fabrica_celdas_estandar.dart';
import '../domain/grafo_tablero.dart';
import '../domain/niveles/dificultad.dart';
import '../domain/progreso/i_cola_sincronizacion.dart';
import '../domain/puntuacion/definicion_nivel.dart';
import '../domain/ranking/ranking_dto.dart';
import '../domain/sesion/sesion_juego.dart';
import '../domain/tablero.dart';
import '../domain/value_objects/presupuesto_movimientos.dart';
import '../domain/value_objects/posicion.dart';
import '../core/configuracion_manager.dart';
import '../infrastructure/audio/audio_service_imp.dart';
import '../infrastructure/preferencias/preferencias_usuario_persistente.dart';
import '../infrastructure/datasources/cargador_nivel_archivo.dart';
import '../infrastructure/datasources/fuente_autenticacion_http.dart';
import '../infrastructure/datasources/fuente_tablero_memoria.dart';
import '../infrastructure/haptica/haptic_feedback_flutter.dart';
import '../infrastructure/network/cliente_http_autenticado.dart';
import '../infrastructure/niveles/catalogo_niveles_archivo.dart';
import '../infrastructure/niveles/catalogo_niveles_remoto.dart';
import '../infrastructure/niveles/niveles_data_source_http.dart';
import '../infrastructure/observabilidad/medidor_metricas_simple.dart';
import '../infrastructure/observabilidad/registro_consola.dart';
import '../infrastructure/progreso/cola_sincronizacion_local.dart';
import '../infrastructure/progreso/progreso_local_persistente.dart';
import '../infrastructure/progreso/progreso_data_source_http.dart';
import '../infrastructure/progreso/progreso_remoto_data_source_http.dart';
import '../infrastructure/ranking/ranking_data_source_http.dart';
import '../infrastructure/reloj/reloj_timer.dart';
import '../infrastructure/sesion/proveedor_sesion_persistente.dart';
import '../presentation/viewmodels/ajustes_view_model.dart';
import '../presentation/viewmodels/auth_view_model.dart';
import '../presentation/viewmodels/juego_view_model.dart';
import '../presentation/viewmodels/ranking_view_model.dart';
import '../presentation/viewmodels/seleccion_niveles_view_model.dart';
import '../presentation/viewmodels/splash_view_model.dart';
import '../presentation/viewmodels/sync_view_model.dart';

/// Composition root: wires domain, application, infrastructure, and presentation
/// into the object graph that the app consumes.
///
/// No business logic lives here — only construction and wiring.
abstract final class Inyeccion {
  // ---------------------------------------------------------------------------
  // Settings — sound toggle + language / i18n (Ticket 27)
  // ---------------------------------------------------------------------------

  /// The single [PreferenciasUsuario] adapter, backed by `shared_preferences`.
  static PreferenciasUsuario get preferenciasUsuario => _preferenciasUsuario;
  static final PreferenciasUsuarioPersistente _preferenciasUsuario =
      PreferenciasUsuarioPersistente();

  /// The DI-lifetime [ConfiguracionManager] (ADR-0002 — **not** a Singleton).
  ///
  /// Call [configuracionManager.inicializar] exactly once at app startup
  /// (before `runApp`) to hydrate saved settings from storage (AC4).
  static ConfiguracionManager get configuracionManager => _configuracionManager;
  static final ConfiguracionManager _configuracionManager = ConfiguracionManager(
    prefs: _preferenciasUsuario,
    audioControl: AudioServiceImp.instance,
  );

  /// Builds the [AjustesViewModel] for the Settings screen.
  static AjustesViewModel construirAjustesViewModel() =>
      AjustesViewModel(config: _configuracionManager);

  /// The default startup level loaded from `assets/levels/level_01.json` — a
  /// real, hand-crafted, fully-dense interlocking puzzle.
  static const idNivelInicial = 1;

  /// Builds the [JuegoViewModel] for the **file-backed** startup level
  /// (`level_01.json`), loaded asynchronously through the file strategy
  /// ([GeneracionPorArchivoNivel], ticket 05). This is the app's default entry
  /// point (`main.dart`).
  ///
  /// The board is no longer the hard-coded demo board (ticket 01's
  /// [FuenteTableroMemoria]). The loaded layout passes the solvability gate;
  /// should loading fail or the level be unsolvable, this throws so the caller
  /// (a `FutureBuilder`) can show an error state.
  static Future<JuegoViewModel> construirJuegoViewModelDesdeArchivo(
    int idNivel, {
    String? nivelIdRemoto,
    Dificultad dificultad = Dificultad.facil,
  }) async {
    final tablero = await generadorPorArchivo.generarAsync(
      // Dimensions are taken from the level file itself; this placeholder is
      // overwritten by `generarAsync` once the definition is read.
      const ConfiguracionGeneracion(filas: 0, columnas: 0),
      idNivel: idNivel,
    );
    if (tablero == null) {
      throw StateError(
        'No se pudo cargar el nivel $idNivel (ausente o no resoluble).',
      );
    }
    return _construirJuegoViewModel(
      tablero,
      idNivel: idNivel,
      nivelIdRemoto: nivelIdRemoto,
      dificultad: dificultad,
    );
  }

  /// Builds the [JuegoViewModel] for a **randomly generated** level (the
  /// [GeneradorNivelBase] backward-carving strategy, which guarantees a solvable,
  /// fully-dense, interlocking layout via the solvability gate). Synchronous —
  /// handy for an offline "new random board" entry point.
  static JuegoViewModel construirJuegoViewModel() {
    return _construirJuegoViewModel(_generarTableroAleatorio());
  }

  /// Margin added to the move budget (Ticket 30): extra moves beyond the exact
  /// arrow count so the player has some room for error.
  static const _margenMovimientos = 5;

  /// Countdown length for a **medium** level (1:00).
  static const _limiteMedio = Duration(minutes: 1);

  /// Countdown length for a **hard** level (0:40, tighter than medium).
  static const _limiteDificil = Duration(seconds: 40);

  /// The countdown length for a level of [dificultad], or `null` when the level
  /// is **untimed**.
  ///
  /// Only medium and hard levels are timed; easy levels have no clock at all.
  /// These durations are gameplay tuning — adjust them here in one place.
  static Duration? limiteTiempoPorDificultad(Dificultad dificultad) {
    return switch (dificultad) {
      Dificultad.facil => null,
      Dificultad.medio => _limiteMedio,
      Dificultad.dificil => _limiteDificil,
    };
  }

  /// Counts unique arrow paths on [tablero], across every depth layer
  /// (ticket 36) — a 2D board's `profundo` is always `1`, so this is
  /// unchanged for every flat catalog level.
  static int _contarFlechas(Tablero tablero) {
    final ids = <int>{};
    for (var f = 0; f < tablero.filas; f++) {
      for (var c = 0; c < tablero.columnas; c++) {
        for (var p = 0; p < tablero.profundo; p++) {
          final celda =
              tablero.celdaEn(Posicion.en(fila: f, columna: c, capa: p));
          if (celda is CeldaFlecha) {
            ids.add(celda.idFlecha);
          }
        }
      }
    }
    return ids.length;
  }

  /// Shared wiring for both entry points: opens a [SesionJuego] with a move
  /// budget — timed only when [dificultad] is medium/hard — builds the use case,
  /// restores the Observer chain ([AudioServiceImp] subscribes to the publisher,
  /// ticket 07) and returns the ViewModel (which auto-subscribes itself).
  static JuegoViewModel _construirJuegoViewModel(
    Tablero tablero, {
    int idNivel = idNivelInicial,
    String? nivelIdRemoto,
    Dificultad dificultad = Dificultad.facil,
  }) {
    const definicion = definicionNivelInicial;

    // Move budget = arrows + error margin (Ticket 30).
    final flechas = _contarFlechas(tablero);
    final presupuesto = PresupuestoMovimientos(flechas + _margenMovimientos);

    // The countdown exists only on medium/hard levels: open the session timed
    // there and untimed (no clock) on easy ones. Because the ViewModel keys its
    // tick off the session, this single decision drives both the visible clock
    // and whether it counts down.
    final sesion = SesionJuego(
      tablero: tablero,
      limiteTiempo: limiteTiempoPorDificultad(dificultad),
      presupuestoMovimientos: presupuesto,
    );

    final moverFlecha = MoverFlechaUseCase(tablero, sesion: sesion);

    // Observer chain (ticket 07): audio reacts to game events without the use
    // case ever referencing infrastructure. The ViewModel subscribes itself.
    moverFlecha.publicador.suscribir(AudioServiceImp.instance);

    return JuegoViewModel(
      tablero: tablero,
      moverFlecha: moverFlecha,
      definicionNivel: definicion,
      reloj: RelojTimer(),
      // Ticket 13: tie the run to its level and persist completion on victory so
      // the next level unlocks.
      idNivel: idNivel,
      // Ticket 35: difficulty gates the hint button (Rule A) — the same value
      // that decides whether the level is timed.
      dificultad: dificultad,
      // Backend level UUID — the identity a synced run is keyed by. Null for the
      // offline/random board, which disables sync for that run.
      nivelIdRemoto: nivelIdRemoto,
      progreso: progresoLocal,
      // Ticket 15: wire sync so victory enqueues the run and flushes to backend.
      sincronizar: sincronizarProgresoUseCase,
      // Surface a failed background sync (e.g. expired token → 401) instead of
      // swallowing it, so the leaderboard can warn rather than show stale data.
      registro: registro,
      audioControl: AudioServiceImp.instance,
      // Ticket 28: buzz the device on an invalid move, behind a port so no
      // Flutter/haptic symbol reaches domain/application (DIP).
      haptica: HapticFeedbackFlutter(),
    );
  }

  /// Dimensions of a randomly generated startup level.
  static const _configAleatorio =
      ConfiguracionGeneracion(filas: 5, columnas: 5);

  /// Generates a board with the random strategy. The backward-carving generator
  /// always yields a solvable, fully-dense board, but should the gate ever
  /// reject a layout we fall back to the demo board rather than hand the UI a
  /// `null`.
  static Tablero _generarTableroAleatorio() {
    return generadorAleatorio.generar(_configAleatorio) ?? _tableroDemo();
  }

  /// The original ticket-01 demo board, kept only as a defensive fallback.
  static Tablero _tableroDemo() {
    const fuente = FuenteTableroMemoria();
    const fabrica = FabricaCeldasEstandar();
    return GrafoTablero.desde(
      filas: fuente.filas,
      columnas: fuente.columnas,
      trayectorias:
          fuente.cargarTrayectorias().map(fabrica.crearTrayectoria).toList(),
      celdas: fuente.cargarParedes().map(fabrica.crear).toList(),
    );
  }

  /// Scoring tuning shared by every level (move-based scoring).
  ///
  /// Timing is **not** taken from here anymore: the countdown is opened on the
  /// session per difficulty via [limiteTiempoPorDificultad], so this definition
  /// carries no `limiteTiempo`.
  static const definicionNivelInicial = DefinicionNivel(
    id: 1,
    numero: 1,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,
    esBonus: false,
  );

  static GeneradorNivelBase get generadorAleatorio =>
      GeneracionAleatoriaNivel();

  static CargadorNivel get cargadorNivelArchivo =>
      const CargadorNivelArchivo();

  static GeneracionPorArchivoNivel get generadorPorArchivo =>
      GeneracionPorArchivoNivel(cargador: cargadorNivelArchivo);

  // ---------------------------------------------------------------------------
  // Meta-game loop & progression (Ticket 13, DM §10)
  // ---------------------------------------------------------------------------

  /// The single local progression store — persisted via `shared_preferences`.
  /// This is the unlock source of truth, distinct from the upload queue.
  static ConsultaProgresoLocal get progresoLocal => _progresoLocal;
  static final ProgresoLocalPersistente _progresoLocal =
      ProgresoLocalPersistente();

  /// The bundled-level catalog used as offline fallback.
  static const CatalogoNivelesArchivo _catalogoNivelesArchivo =
      CatalogoNivelesArchivo();

  /// The remote catalog with local asset fallback (Ticket 17).
  ///
  /// Lazy initialised because [_clienteHttp] is declared later in this class.
  static CatalogoNiveles get catalogoNiveles => _catalogoNiveles;
  static CatalogoNivelesRemoto get _catalogoNiveles => _catalogoNivelesImple;
  static final CatalogoNivelesRemoto _catalogoNivelesImple =
      CatalogoNivelesRemoto(
    client: _clienteHttp,
    fallback: _catalogoNivelesArchivo,
  );

  /// The active-user selector — the same store instance as [progresoLocal],
  /// used to switch the local-progress namespace on login/register.
  static SelectorUsuarioProgreso get selectorUsuarioProgreso => _progresoLocal;

  /// Use case that activates a signed-in account's device-local progression
  /// (switches the per-user namespace + clears the pending-sync queue) so each
  /// user sees their own retained unlocks and none leak across accounts.
  static ActivarProgresoUsuarioUseCase get activarProgresoUsuarioUseCase =>
      ActivarProgresoUsuarioUseCase(
        selector: selectorUsuarioProgreso,
        cola: colaSincronizacion,
      );

  /// Use case that joins the catalog with progression state and the unlock rule.
  static ObtenerNivelesUseCase get obtenerNivelesUseCase =>
      ObtenerNivelesUseCase(
        catalogo: catalogoNiveles,
        progreso: progresoLocal,
      );

  /// Use case that reads server-side progression on login and merges it into
  /// the local store keeping the best per-level (Ticket 24, AC2/AC3).
  static RestaurarProgresoUseCase get restaurarProgresoUseCase =>
      RestaurarProgresoUseCase(
        consultaRemoto: fuenteProgresoRemoto,
        progresoLocal: progresoLocal,
        catalogo: catalogoNiveles,
        // Surface a failed login-restore (offline, 401, response-shape drift)
        // instead of degrading silently to a from-scratch Level Select.
        registro: registro,
      );

  /// Builds the [SeleccionNivelesViewModel] for the Level Selection screen.
  static SeleccionNivelesViewModel construirSeleccionNivelesViewModel() {
    return SeleccionNivelesViewModel(obtenerNiveles: obtenerNivelesUseCase);
  }

  // ---------------------------------------------------------------------------
  // Identity & Session (ticket 08)
  // ---------------------------------------------------------------------------

  /// The single injected [ProveedorSesion] instance — wired once at the
  /// composition root, never a static/global accessor (ADR-0002). Persisted via
  /// `shared_preferences` so the JWT survives restarts (Issue 14, AC3).
  static ProveedorSesion get proveedorSesion => _proveedorSesion;
  static final ProveedorSesionPersistente _proveedorSesion =
      ProveedorSesionPersistente();

  /// The single authenticated HTTP client — the Bearer interceptor (Issue 14,
  /// AC3). Every protected data source shares this so the token is attached
  /// transparently and exactly once, in infrastructure.
  static ClienteHttpAutenticado get clienteHttp => _clienteHttp;
  static final ClienteHttpAutenticado _clienteHttp =
      ClienteHttpAutenticado(proveedorSesion: _proveedorSesion);

  /// The single injected [FuenteAutenticacion] instance backed by HTTP. It uses
  /// the authenticated client so `/auth/me` is automatically authorized while
  /// the public register/login routes simply carry no token.
  static FuenteAutenticacion get fuenteAutenticacion => _fuenteAutenticacion;
  static final FuenteAutenticacionHttp _fuenteAutenticacion =
      FuenteAutenticacionHttp(client: _clienteHttp);

  static RegistrarUsuarioUseCase get registrarUsuarioUseCase =>
      RegistrarUsuarioUseCase(
        fuenteAutenticacion: fuenteAutenticacion,
        proveedorSesion: proveedorSesion,
        activarProgreso: activarProgresoUsuarioUseCase,
      );

  static IniciarSesionUseCase get iniciarSesionUseCase =>
      IniciarSesionUseCase(
        fuenteAutenticacion: fuenteAutenticacion,
        proveedorSesion: proveedorSesion,
        activarProgreso: activarProgresoUsuarioUseCase,
      );

  /// Use case reading the authenticated principal (`GET /auth/me`).
  static ObtenerPerfilUseCase get obtenerPerfilUseCase =>
      ObtenerPerfilUseCase(fuenteAutenticacion: fuenteAutenticacion);

  // ---------------------------------------------------------------------------
  // Level authoring (Issue 14 — POST /levels, protected)
  // ---------------------------------------------------------------------------

  static FuenteNiveles get fuenteNiveles => _fuenteNiveles;
  static final NivelesDataSourceHttp _fuenteNiveles =
      NivelesDataSourceHttp(client: _clienteHttp);

  static CrearNivelUseCase get crearNivelUseCase =>
      CrearNivelUseCase(fuenteNiveles: fuenteNiveles);

  static CerrarSesionUseCase get cerrarSesionUseCase =>
      CerrarSesionUseCase(proveedorSesion: proveedorSesion);

  /// Builds the [SplashViewModel] for the launch screen (Ticket 33). The
  /// auth-state probe reuses the injected [proveedorSesion] — no duplicate
  /// session logic — and the min-visible/timeout defaults live in the ViewModel.
  static SplashViewModel construirSplashViewModel() =>
      SplashViewModel(proveedorSesion: proveedorSesion);

  /// Builds the [AuthViewModel] with all dependencies injected.
  static AuthViewModel construirAuthViewModel() {
    return AuthViewModel(
      proveedorSesion: proveedorSesion,
      cerrarSesion: cerrarSesionUseCase,
      registrarUsuario: registrarUsuarioUseCase,
      iniciarSesion: iniciarSesionUseCase,
      restaurarProgreso: restaurarProgresoUseCase,
      // Validate a persisted token against `GET /auth/me` on startup so a stale
      // or invalid session drops the user on the login screen instead of
      // silently auto-forwarding to Level Select.
      verificarPerfil: obtenerPerfilUseCase,
    );
  }

  // ---------------------------------------------------------------------------
  // Offline Progress Sync (ticket 10)
  // ---------------------------------------------------------------------------

  static IColaSincronizacion get colaSincronizacion => _colaSincronizacion;
  static final ColaSincronizacionLocal _colaSincronizacion =
      ColaSincronizacionLocal();

  static IRepositorioProgreso get repositorioProgreso => _repositorioProgreso;
  static final ProgresoDataSourceHttp _repositorioProgreso =
      ProgresoDataSourceHttp(client: _clienteHttp);

  /// Remote progression read port — `GET /progress` (Ticket 24). Used by
  /// [RestaurarProgresoUseCase] to fetch server-side unlocks on login.
  static IConsultaProgresoRemoto get fuenteProgresoRemoto => _fuenteProgresoRemoto;
  static final ProgresoRemotoDataSourceHttp _fuenteProgresoRemoto =
      ProgresoRemotoDataSourceHttp(client: _clienteHttp, registro: _registro);

  static SincronizarProgresoUseCase get sincronizarProgresoUseCase =>
      SincronizarProgresoUseCase(
        cola: colaSincronizacion,
        repositorio: repositorioProgreso,
      );

  static SyncViewModel construirSyncViewModel() {
    return SyncViewModel(
      sincronizarProgreso: sincronizarProgresoUseCase,
    );
  }

  // ---------------------------------------------------------------------------
  // Leaderboard read-only (ticket 11, DM-B5, E3)
  // ---------------------------------------------------------------------------

  static IConsultaRanking get consultaRanking => _consultaRanking;
  static final RankingDataSourceHttp _consultaRanking =
      RankingDataSourceHttp(client: _clienteHttp);

  static ConsultarRankingUseCase get consultarRankingUseCase =>
      ConsultarRankingUseCase(consulta: consultaRanking);

  static RankingViewModel construirRankingViewModel() {
    return RankingViewModel(consulta: consultaRanking);
  }

  // ---------------------------------------------------------------------------
  // Cross-cutting concerns via Decorator (ticket 12, DM-F9, ADR-0004)
  // ---------------------------------------------------------------------------
  //
  // Metrics, logging and security are added by *composition* around use cases.
  // The use cases themselves are never edited to gain these concerns, and no
  // logging/metrics library reaches the application or domain layers — the
  // concrete adapters live only here in infrastructure ("AOP via SOLID").

  /// The single injected logging sink — a console adapter wired once here.
  static IRegistro get registro => _registro;
  static const RegistroConsola _registro = RegistroConsola();

  /// The single injected metrics meter — in-memory, swappable for an exporter.
  static IMedidorMetricas get medidorMetricas => _medidorMetricas;
  static final MedidorMetricasSimple _medidorMetricas = MedidorMetricasSimple();

  /// The leaderboard read lifted into an [ICasoDeUso] and wrapped in the full
  /// cross-cutting stack — **security → logging → metrics → use case**.
  ///
  /// [ConsultarRankingUseCase] is untouched: it is adapted via
  /// [CasoDeUsoAccion] and decorated here. The security layer makes this an
  /// authenticated leaderboard fetch by reading the token through the injected
  /// [proveedorSesion], never a static accessor (AC3). This getter is the
  /// canonical place to assemble such stacks for any chosen use case.
  static ICasoDeUso<({String nivelId, int limite}), RankingDto>
      get consultarRankingDecorado {
    final base = CasoDeUsoAccion<({String nivelId, int limite}), RankingDto>(
      (entrada) => consultarRankingUseCase.obtenerTop(
        nivelId: entrada.nivelId,
        limite: entrada.limite,
      ),
    );
    return DecoradorSeguridadCasoDeUso(
      DecoradorRegistroCasoDeUso(
        DecoradorMetricasCasoDeUso(
          base,
          metricas: medidorMetricas,
          nombre: 'ConsultarRanking',
        ),
        registro: registro,
        nombre: 'ConsultarRanking',
      ),
      sesion: proveedorSesion,
    );
  }
}
