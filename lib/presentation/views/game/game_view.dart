import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/game_theme.dart';
import '../../../domain/value_objects/direccion.dart';
import '../../../domain/value_objects/posicion.dart';
import '../../viewmodels/juego_view_model.dart';
import '../../viewmodels/juego_view_state.dart';

/// The board screen — a thin View that only draws.
///
/// It owns no game logic: it observes its [JuegoViewModel] (a `ChangeNotifier`)
/// and forwards taps to `viewModel.tocar(...)`. All colour, spacing and radius
/// come from the theme tokens (`GameTheme`, `AppSpacing`, `AppRadii`), never
/// hard-coded here.
class GameView extends StatefulWidget {
  /// Creates the board screen bound to [viewModel].
  const GameView({required this.viewModel, super.key});

  /// The view model this screen renders and forwards taps to.
  final JuegoViewModel viewModel;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = Theme.of(context).extension<GameTheme>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('ArrowMaze')),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final estado = widget.viewModel.estado;
          return Column(
            children: [
              _Hud(movimientos: estado.movimientos),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _Tablero(
                        estado: estado,
                        game: game,
                        onTap: widget.viewModel.tocar,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The moves counter strip.
class _Hud extends StatelessWidget {
  const _Hud({required this.movimientos});

  final int movimientos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Moves: ', style: AppTypography.bodyMedium),
          Text('$movimientos', style: AppTypography.hudNumber),
        ],
      ),
    );
  }
}

/// The grid of cells, laid out row by row.
class _Tablero extends StatelessWidget {
  const _Tablero({
    required this.estado,
    required this.game,
    required this.onTap,
  });

  final JuegoViewState estado;
  final GameTheme game;
  final void Function(Posicion posicion) onTap;

  @override
  Widget build(BuildContext context) {
    final tablero = estado.tablero;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: game.boardBackground,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            for (var fila = 0; fila < tablero.filas; fila++)
              Expanded(
                child: Row(
                  children: [
                    for (var columna = 0; columna < tablero.columnas; columna++)
                      Expanded(
                        child: _Celda(
                          celda: tablero.celdas[fila * tablero.columnas + columna],
                          game: game,
                          onTap: onTap,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One tappable cell.
class _Celda extends StatelessWidget {
  const _Celda({
    required this.celda,
    required this.game,
    required this.onTap,
  });

  final CeldaUI celda;
  final GameTheme game;
  final void Function(Posicion posicion) onTap;

  @override
  Widget build(BuildContext context) {
    final esFlecha = celda.tipo == TipoCeldaUI.flecha;
    return GestureDetector(
      onTap: esFlecha ? () => onTap(celda.posicion) : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: AnimatedContainer(
          duration: AppDurations.normal,
          decoration: BoxDecoration(
            color: _relleno(),
            borderRadius: BorderRadius.circular(AppRadii.cell),
            border: Border.all(color: game.boardGridLine),
            boxShadow: esFlecha
                ? [
                    BoxShadow(
                      color: game.cellArrowGlow.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: esFlecha ? _flecha() : null,
        ),
      ),
    );
  }

  Color _relleno() {
    switch (celda.tipo) {
      case TipoCeldaUI.flecha:
        return game.cellArrow;
      case TipoCeldaUI.pared:
        return game.cellWall;
      case TipoCeldaUI.vacia:
        return game.cellEmpty;
    }
  }

  Widget _flecha() {
    return Center(
      child: Transform.rotate(
        angle: _angulo(celda.direccion!),
        child: const Icon(Icons.arrow_upward, color: Colors.black),
      ),
    );
  }

  /// Maps a [Direccion] to a rotation of the upward arrow icon.
  double _angulo(Direccion direccion) {
    if (direccion == Direccion.abajo) return math.pi;
    if (direccion == Direccion.izquierda) return -math.pi / 2;
    if (direccion == Direccion.derecha) return math.pi / 2;
    return 0;
  }
}
