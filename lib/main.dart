import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'di/inyeccion.dart';
import 'presentation/viewmodels/juego_view_model.dart';
import 'presentation/views/auth/auth_view.dart';
import 'presentation/views/game/game_view.dart';
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
  );
}

/// Pushes the game host for [idNivel]; [idsOrdenados] lets the host offer "Next".
void _abrirNivel(BuildContext context, int idNivel, List<int> idsOrdenados) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _JuegoHost(idNivel: idNivel, idsOrdenados: idsOrdenados),
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
  const _JuegoHost({required this.idNivel, required this.idsOrdenados});

  final int idNivel;
  final List<int> idsOrdenados;

  @override
  State<_JuegoHost> createState() => _JuegoHostState();
}

class _JuegoHostState extends State<_JuegoHost> {
  late final Future<JuegoViewModel> _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = Inyeccion.construirJuegoViewModelDesdeArchivo(widget.idNivel);
  }

  /// The next level's id in catalog order, or `null` when this is the last one.
  int? get _siguienteNivel {
    final i = widget.idsOrdenados.indexOf(widget.idNivel);
    if (i < 0 || i + 1 >= widget.idsOrdenados.length) return null;
    return widget.idsOrdenados[i + 1];
  }

  void _reintentar() => _reemplazarCon(widget.idNivel);

  void _siguiente() {
    final next = _siguienteNivel;
    if (next != null) _reemplazarCon(next);
  }

  void _reemplazarCon(int idNivel) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            _JuegoHost(idNivel: idNivel, idsOrdenados: widget.idsOrdenados),
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
    viewModel.cargarRanking(idNivel: widget.idNivel, limite: 10);
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
                  'Could not load level ${widget.idNivel}.',
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
