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
      home: GameView(viewModel: Inyeccion.construirJuegoViewModel()),
    );
  }
}
