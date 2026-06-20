import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'di/inyeccion.dart';
import 'presentation/views/game/game_view.dart';

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
      // Default entry point: generate a fresh random puzzle on every launch via
      // the reverse-carving generator (fully dense, bending, interlocking and
      // solvable by construction). The async file-loader path remains available
      // through `Inyeccion.construirJuegoViewModelDesdeArchivo()` for future use.
      home: GameView(viewModel: Inyeccion.construirJuegoViewModel()),
    );
  }
}
