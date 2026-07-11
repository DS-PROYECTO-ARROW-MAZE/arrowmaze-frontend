import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'core/i18n/cadenas_scope.dart';
import 'core/i18n/localizaciones_provider.dart';
import 'core/theme/app_theme.dart';
import 'di/inyeccion.dart';
import 'presentation/viewmodels/juego_view_model.dart';
import 'presentation/viewmodels/splash_view_model.dart';
import 'presentation/views/auth/auth_view.dart';
import 'presentation/views/game/game_view.dart';
import 'presentation/views/ranking/ranking_view.dart';
import 'presentation/views/seleccion/seleccion_niveles_view.dart';
import 'presentation/views/settings/ajustes_view.dart';
import 'presentation/views/splash/splash_view.dart';
import 'presentation/viewmodels/seleccion_niveles_view_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect device locale and default to it on first run (AC5).
  final deviceLocale =
      SchedulerBinding.instance.platformDispatcher.locale.languageCode;
  final idiomaFallback = ['en', 'es'].contains(deviceLocale) ? deviceLocale : 'en';

  // Hydrate saved settings before the first frame so the locale and mute flag
  // are correct from frame 1 (AC4).
  await Inyeccion.configuracionManager.inicializar(
    idiomaFallback: idiomaFallback,
  );

  runApp(const MyApp());
}

/// Root of the ArrowMaze app.
class MyApp extends StatelessWidget {
  /// Creates the app shell.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArrowMaze',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      // Wrap all content in a locale-reactive CadenasScope so every View can
      // call CadenasScope.of(context) for i18n strings. Rebuilds only the
      // scope (not the Navigator) when the locale changes (AC3).
      builder: (context, child) => _LocaleScope(child: child!),
      // Meta-game loop (Ticket 13): Splash → (Auth | Level Select) → Game →
      // (Next/Retry/Menu). Each builder below is the composition root for its
      // route — it asks [Inyeccion] for fresh ViewModels so the Views never touch
      // the DI graph. The launch screen (Ticket 33) is the home; it routes on its
      // own completion by session state.
      home: const _ArranqueSplash(),
    );
  }
}

/// Composition-root host for the launch splash (Ticket 33).
///
/// Builds the [SplashViewModel] once, shows [SplashView], and — once the fade-out
/// finishes — replaces itself with the correct destination by session state:
/// Level Selection when a session exists, the login screen otherwise (AC5). The
/// splash is a one-time launch screen: routing uses [Navigator.pushReplacement]
/// so it is not re-shown on in-app navigation (AC6).
class _ArranqueSplash extends StatefulWidget {
  const _ArranqueSplash();

  @override
  State<_ArranqueSplash> createState() => _ArranqueSplashState();
}

class _ArranqueSplashState extends State<_ArranqueSplash> {
  late final SplashViewModel _viewModel = Inyeccion.construirSplashViewModel();

  void _rutear() {
    if (!mounted) return;
    final destino = _viewModel.haySesion ? _construirSeleccion : _construirAuth;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: destino),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SplashView(viewModel: _viewModel, alCompletar: _rutear);
  }
}

/// Builds the Register / Login screen (the no-session destination after splash).
Widget _construirAuth(BuildContext context) => AuthView(
      viewModel: Inyeccion.construirAuthViewModel(),
      construirInicio: _construirSeleccion,
    );

/// Reactive locale wrapper placed inside MaterialApp.builder.
///
/// Listens to [ConfiguracionManager] for idioma changes and rebuilds the
/// [CadenasScope] in the tree, triggering live string refresh in all Views
/// that depend on [CadenasScope.of] (AC3). The Navigator and route stack are
/// unaffected by the rebuild — only string values change.
class _LocaleScope extends StatelessWidget {
  const _LocaleScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Inyeccion.configuracionManager,
      builder: (context, _) => CadenasScope(
        cadenas: LocalizacionesProvider.cadenasPara(
          Inyeccion.configuracionManager.idioma,
        ),
        child: child,
      ),
    );
  }
}

/// Builds the Level Selection menu and kicks off the catalog load (with locks
/// and stars). Tapping an unlocked level opens it via [_abrirNivel].
/// The Settings button opens [AjustesView] (AC1 — reachable after login).
Widget _construirSeleccion(BuildContext context) {
  final viewModel = Inyeccion.construirSeleccionNivelesViewModel();
  viewModel.cargar();
  return SeleccionNivelesView(
    viewModel: viewModel,
    alSeleccionar: _abrirNivel,
    onLogout: () => _cerrarSesionYVolverALogin(context),
    onAjustes: () => _abrirAjustes(context),
  );
}

/// Pushes the Settings screen (AC1).
void _abrirAjustes(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AjustesView(
        viewModel: Inyeccion.construirAjustesViewModel(),
      ),
    ),
  );
}

/// Clears the session token and replaces the entire stack with a fresh login
/// screen (AC2, AC3).
void _cerrarSesionYVolverALogin(BuildContext context) {
  final navigator = Navigator.of(context);
  Inyeccion.cerrarSesionUseCase.ejecutar().then((_) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthView(
          viewModel: Inyeccion.construirAuthViewModel(),
          construirInicio: _construirSeleccion,
        ),
      ),
      (_) => false,
    );
  });
}

/// Pushes the game host for [nivel]; [nivelesOrdenados] lets the host offer
/// "Next" and carries each level's backend UUID for sync/leaderboard.
void _abrirNivel(
  BuildContext context,
  NivelResumenUI nivel,
  List<NivelResumenUI> nivelesOrdenados,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          _JuegoHost(nivel: nivel, nivelesOrdenados: nivelesOrdenados),
    ),
  );
}

/// Loads the board for one level and hosts the [GameView], wiring the post-game
/// Next / Retry / Level-Select navigation.
///
/// Lives in the composition root (not `presentation/`) so the Views stay free of
/// the DI graph. The board load is asynchronous (file-backed level), so this is
/// the `FutureBuilder` loading shell promised in DIAGRAM-RECONCILIATION.md §9.1.
class _JuegoHost extends StatefulWidget {
  const _JuegoHost({required this.nivel, required this.nivelesOrdenados});

  final NivelResumenUI nivel;
  final List<NivelResumenUI> nivelesOrdenados;

  @override
  State<_JuegoHost> createState() => _JuegoHostState();
}

class _JuegoHostState extends State<_JuegoHost> {
  late final Future<JuegoViewModel> _viewModel;

  /// The resolved game ViewModel, captured once the board finishes loading so
  /// the leaderboard builder can await its in-flight progress sync.
  JuegoViewModel? _juego;

  @override
  void initState() {
    super.initState();
    // The board is loaded from the bundled asset by ordinal (`id`); the backend
    // UUID (`idRemoto`) is forwarded so a victory syncs against the right level.
    _viewModel = Inyeccion.construirJuegoViewModelDesdeArchivo(
      widget.nivel.id,
      nivelIdRemoto: widget.nivel.idRemoto,
      // Timer presence follows the level's difficulty (medium/hard timed, easy
      // untimed) — decided in the composition root from this metadata.
      dificultad: widget.nivel.dificultad,
    );
    _viewModel.then((vm) => _juego = vm);
  }

  /// The next level in catalog order, or `null` when this is the last one.
  NivelResumenUI? get _siguienteNivel {
    final i = widget.nivelesOrdenados.indexWhere((n) => n.id == widget.nivel.id);
    if (i < 0 || i + 1 >= widget.nivelesOrdenados.length) return null;
    return widget.nivelesOrdenados[i + 1];
  }

  void _reintentar() => _reemplazarCon(widget.nivel);

  void _siguiente() {
    final next = _siguienteNivel;
    if (next != null) _reemplazarCon(next);
  }

  void _reemplazarCon(NivelResumenUI nivel) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _JuegoHost(
          nivel: nivel,
          nivelesOrdenados: widget.nivelesOrdenados,
        ),
      ),
    );
  }

  /// Returns to a freshly-loaded Level Selection (so unlocks/stars reflect the
  /// run that just ended).
  void _menu() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: _construirSeleccion),
    );
  }

  /// Builds the leaderboard for *this* level and starts its load.
  Widget _construirRanking(BuildContext context) {
    final viewModel = Inyeccion.construirRankingViewModel();
    // The leaderboard API keys by the backend level UUID. It is available only
    // when the catalog was served by the backend; offline (bundled catalog) it
    // is null, and the read surfaces an empty/error state gracefully.
    //
    // Pass the in-flight victory sync so the read waits for the
    // `POST /progress/sync` write to resolve before fetching — the score just
    // earned is reflected and the GET never races the POST. `null` when no run
    // is syncing (e.g. opening the board before winning).
    viewModel.cargarRanking(
      nivelId: widget.nivel.idRemoto ?? '',
      limite: 10,
      sincronizacionPendiente: _juego?.sincronizacionEnCurso,
    );
    return RankingView(viewModel: viewModel);
  }

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _menu();
      },
      child: FutureBuilder<JuegoViewModel>(
        future: _viewModel,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: Text(s.pantallaJuego)),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.noPudoCargarNivel(widget.nivel.id),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return GameView(
            viewModel: snapshot.data!,
            construirRanking: _construirRanking,
            onReintentar: _reintentar,
            onSiguiente: _siguienteNivel == null ? null : _siguiente,
            onMenu: _menu,
          );
        },
      ),
    );
  }
}
