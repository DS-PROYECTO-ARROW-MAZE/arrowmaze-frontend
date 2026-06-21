import '../application/decoradores/caso_de_uso_accion.dart';
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
import '../application/ports/i_consulta_ranking.dart';
import '../application/ports/i_medidor_metricas.dart';
import '../application/ports/i_registro.dart';
import '../application/ports/i_repositorio_progreso.dart';
import '../application/ports/proveedor_sesion.dart';
import '../application/use_cases/consultar_ranking_use_case.dart';
import '../application/use_cases/iniciar_sesion_use_case.dart';
import '../application/use_cases/mover_flecha_use_case.dart';
import '../application/use_cases/obtener_niveles_use_case.dart';
import '../application/use_cases/registrar_usuario_use_case.dart';
import '../application/use_cases/sincronizar_progreso_use_case.dart';
import '../domain/entities/fabrica_celdas_estandar.dart';
import '../domain/grafo_tablero.dart';
import '../domain/progreso/i_cola_sincronizacion.dart';
import '../domain/puntuacion/definicion_nivel.dart';
import '../domain/ranking/ranking_dto.dart';
import '../domain/sesion/sesion_juego.dart';
import '../domain/tablero.dart';
import '../infrastructure/audio/audio_service_imp.dart';
import '../infrastructure/datasources/cargador_nivel_archivo.dart';
import '../infrastructure/datasources/fuente_autenticacion_http.dart';
import '../infrastructure/datasources/fuente_tablero_memoria.dart';
import '../infrastructure/niveles/catalogo_niveles_archivo.dart';
import '../infrastructure/observabilidad/medidor_metricas_simple.dart';
import '../infrastructure/observabilidad/registro_consola.dart';
import '../infrastructure/progreso/cola_sincronizacion_local.dart';
import '../infrastructure/progreso/progreso_local_persistente.dart';
import '../infrastructure/progreso/progreso_data_source_http.dart';
import '../infrastructure/ranking/ranking_data_source_http.dart';
import '../infrastructure/reloj/reloj_timer.dart';
import '../infrastructure/sesion/proveedor_sesion_impl.dart';
import '../presentation/viewmodels/auth_view_model.dart';
import '../presentation/viewmodels/juego_view_model.dart';
import '../presentation/viewmodels/ranking_view_model.dart';
import '../presentation/viewmodels/seleccion_nivel_view_model.dart';
import '../presentation/viewmodels/seleccion_niveles_view_model.dart';
import '../presentation/viewmodels/sync_view_model.dart';

/// Composition root: wires domain, application, infrastructure, and presentation
/// into the object graph that the app consumes.
///
/// No business logic lives here — only construction and wiring.
abstract final class Inyeccion {
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
  static Future<JuegoViewModel> construirJuegoViewModelDesdeArchivo([
    int idNivel = idNivelInicial,
  ]) async {
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
    return _construirJuegoViewModel(tablero, idNivel: idNivel);
  }

  /// Builds the [JuegoViewModel] for a **randomly generated** level (the
  /// [GeneradorNivelBase] backward-carving strategy, which guarantees a solvable,
  /// fully-dense, interlocking layout via the solvability gate). Synchronous —
  /// handy for an offline "new random board" entry point.
  static JuegoViewModel construirJuegoViewModel() {
    return _construirJuegoViewModel(_generarTableroAleatorio());
  }

  /// Shared wiring for both entry points: opens a **timed** [SesionJuego] from
  /// [definicionNivelInicial], builds the use case, restores the Observer chain
  /// ([AudioServiceImp] subscribes to the publisher, ticket 07) and returns the
  /// ViewModel (which auto-subscribes itself).
  static JuegoViewModel _construirJuegoViewModel(
    Tablero tablero, {
    int idNivel = idNivelInicial,
  }) {
    const definicion = definicionNivelInicial;

    // Open the session here (instead of letting the use case default to an
    // untimed one) so the level carries the time limit from its definition.
    final sesion = SesionJuego(
      tablero: tablero,
      limiteTiempo: definicion.limiteTiempo,
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
      progreso: progresoLocal,
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

  /// Scoring/timing definition for the startup level. `limiteTiempo` makes the
  /// level timed, driving the HUD clock and enabling the defeat transition.
  static const definicionNivelInicial = DefinicionNivel(
    id: 1,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,
    umbralesEstrellas: [300, 600, 900],
    limiteTiempo: Duration(seconds: 90),
  );

  static GeneradorNivelBase get generadorAleatorio =>
      const GeneracionAleatoriaNivel();

  static CargadorNivel get cargadorNivelArchivo =>
      const CargadorNivelArchivo();

  static GeneracionPorArchivoNivel get generadorPorArchivo =>
      GeneracionPorArchivoNivel(cargador: cargadorNivelArchivo);

  static SeleccionNivelViewModel construirSeleccionNivelViewModel() {
    return SeleccionNivelViewModel(
      generadorArchivo: generadorPorArchivo,
    );
  }

  // ---------------------------------------------------------------------------
  // Meta-game loop & progression (Ticket 13, DM §10)
  // ---------------------------------------------------------------------------

  /// The single local progression store — persisted via `shared_preferences`.
  /// This is the unlock source of truth, distinct from the upload queue.
  static ConsultaProgresoLocal get progresoLocal => _progresoLocal;
  static final ProgresoLocalPersistente _progresoLocal =
      ProgresoLocalPersistente();

  /// The bundled-level catalog used by the Level Selection screen.
  static CatalogoNiveles get catalogoNiveles => _catalogoNiveles;
  static const CatalogoNivelesArchivo _catalogoNiveles =
      CatalogoNivelesArchivo();

  /// Use case that joins the catalog with progression state and the unlock rule.
  static ObtenerNivelesUseCase get obtenerNivelesUseCase =>
      ObtenerNivelesUseCase(
        catalogo: catalogoNiveles,
        progreso: progresoLocal,
      );

  /// Builds the [SeleccionNivelesViewModel] for the Level Selection screen.
  static SeleccionNivelesViewModel construirSeleccionNivelesViewModel() {
    return SeleccionNivelesViewModel(obtenerNiveles: obtenerNivelesUseCase);
  }

  // ---------------------------------------------------------------------------
  // Identity & Session (ticket 08)
  // ---------------------------------------------------------------------------

  /// The single injected [ProveedorSesion] instance — wired once at the
  /// composition root, never a static/global accessor (ADR-0002).
  static ProveedorSesion get proveedorSesion => _proveedorSesion;
  static final ProveedorSesionImpl _proveedorSesion = ProveedorSesionImpl();

  /// The single injected [FuenteAutenticacion] instance backed by HTTP.
  static FuenteAutenticacion get fuenteAutenticacion => _fuenteAutenticacion;
  static final FuenteAutenticacionHttp _fuenteAutenticacion =
      FuenteAutenticacionHttp();

  static RegistrarUsuarioUseCase get registrarUsuarioUseCase =>
      RegistrarUsuarioUseCase(
        fuenteAutenticacion: fuenteAutenticacion,
        proveedorSesion: proveedorSesion,
      );

  static IniciarSesionUseCase get iniciarSesionUseCase =>
      IniciarSesionUseCase(
        fuenteAutenticacion: fuenteAutenticacion,
        proveedorSesion: proveedorSesion,
      );

  /// Builds the [AuthViewModel] with all dependencies injected.
  static AuthViewModel construirAuthViewModel() {
    return AuthViewModel(
      proveedorSesion: proveedorSesion,
      registrarUsuario: registrarUsuarioUseCase,
      iniciarSesion: iniciarSesionUseCase,
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
      ProgresoDataSourceHttp(proveedorSesion: proveedorSesion);

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
      RankingDataSourceHttp(proveedorSesion: proveedorSesion);

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
  static ICasoDeUso<({int idNivel, int limite}), RankingDto>
      get consultarRankingDecorado {
    final base = CasoDeUsoAccion<({int idNivel, int limite}), RankingDto>(
      (entrada) => consultarRankingUseCase.obtenerTop(
        idNivel: entrada.idNivel,
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
