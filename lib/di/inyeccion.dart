import '../application/generadores/configuracion_generacion.dart';
import '../application/generadores/generacion_aleatoria_nivel.dart';
import '../application/generadores/generacion_por_archivo_nivel.dart';
import '../application/generadores/generador_nivel_base.dart';
import '../application/ports/cargador_nivel.dart';
import '../application/ports/fuente_autenticacion.dart';
import '../application/ports/proveedor_sesion.dart';
import '../application/use_cases/iniciar_sesion_use_case.dart';
import '../application/use_cases/mover_flecha_use_case.dart';
import '../application/use_cases/registrar_usuario_use_case.dart';
import '../domain/entities/fabrica_celdas_estandar.dart';
import '../domain/grafo_tablero.dart';
import '../domain/puntuacion/definicion_nivel.dart';
import '../domain/sesion/sesion_juego.dart';
import '../domain/tablero.dart';
import '../infrastructure/audio/audio_service_imp.dart';
import '../infrastructure/datasources/cargador_nivel_archivo.dart';
import '../infrastructure/datasources/fuente_autenticacion_http.dart';
import '../infrastructure/datasources/fuente_tablero_memoria.dart';
import '../infrastructure/reloj/reloj_timer.dart';
import '../infrastructure/sesion/proveedor_sesion_impl.dart';
import '../presentation/viewmodels/auth_view_model.dart';
import '../presentation/viewmodels/juego_view_model.dart';
import '../presentation/viewmodels/seleccion_nivel_view_model.dart';

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
    return _construirJuegoViewModel(tablero);
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
  static JuegoViewModel _construirJuegoViewModel(Tablero tablero) {
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
}
