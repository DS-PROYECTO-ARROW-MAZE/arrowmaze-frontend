import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'di/inyeccion.dart';
import 'presentation/viewmodels/juego_view_model.dart';
import 'presentation/views/auth/auth_view.dart';
import 'presentation/views/game/game_view.dart';
import 'presentation/viewmodels/seleccion_niveles_view_state.dart';
import 'presentation/views/ranking/ranking_view.dart';
import 'presentation/views/seleccion/seleccion_niveles_view.dart';

void main() {
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
      // Meta-game loop (Ticket 13): Auth → Level Select → Game → (Next/Retry/
      // Menu). Each builder below is the composition root for its route — it asks
      // [Inyeccion] for fresh ViewModels so the Views never touch the DI graph.
      home: AuthView(
        viewModel: Inyeccion.construirAuthViewModel(),
        construirInicio: _construirSeleccion,
      ),
    );
  }
}

/// Builds the Level Selection menu and kicks off the catalog load (with locks
/// and stars). Tapping an unlocked level opens it via [_abrirNivel].
Widget _construirSeleccion(BuildContext context) {
  final viewModel = Inyeccion.construirSeleccionNivelesViewModel();
  viewModel.cargar();
  return SeleccionNivelesView(
    viewModel: viewModel,
    alSeleccionar: _abrirNivel,
    onLogout: () => _cerrarSesionYVolverALogin(context),
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
    return FutureBuilder<JuegoViewModel>(
      future: _viewModel,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('ArrowMaze')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load level ${widget.nivel.id}.',
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
    );
  }
}
