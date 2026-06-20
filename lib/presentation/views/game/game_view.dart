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
/// and forwards taps to `viewModel.tocar(...)`. The board is rendered by a single
/// [_TableroPainter] as **continuous, bending arrow paths** over a plain dark
/// backdrop with subtle dots for empty space — there are no discrete background
/// tiles. All colour, spacing and radius come from theme tokens (`GameTheme`,
/// `AppSpacing`, `AppRadii`), never hard-coded here.
class GameView extends StatefulWidget {
  /// Creates the board screen bound to [viewModel].
  const GameView({required this.viewModel, super.key});

  /// The view model this screen renders and forwards taps to.
  final JuegoViewModel viewModel;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView>
    with SingleTickerProviderStateMixin {
  /// Drives the invalid-tap shake/flash; one short pulse per penalized move.
  late final AnimationController _feedback;

  @override
  void initState() {
    super.initState();
    _feedback = AnimationController(vsync: this, duration: AppDurations.fast);
    widget.viewModel.addListener(_alCambiarEstado);
  }

  /// Fires the feedback pulse whenever the published state reports a penalized
  /// invalid tap. The board itself is never mutated here — only the affordance.
  void _alCambiarEstado() {
    if (widget.viewModel.estado.movimientoInvalido) {
      _feedback.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_alCambiarEstado);
    _feedback.dispose();
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
                      aspectRatio: estado.tablero.columnas / estado.tablero.filas,
                      child: _FeedbackInvalido(
                        animacion: _feedback,
                        game: game,
                        child: _Tablero(
                          estado: estado,
                          game: game,
                          onTap: widget.viewModel.tocar,
                        ),
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

/// Wraps the board with the invalid-tap affordance: a brief horizontal shake and
/// a fading red flash, both keyed to [GameTheme.invalidMoveFlash]. Purely
/// presentational — it never mutates the board, so cells stay byte-identical
/// while the feedback plays.
class _FeedbackInvalido extends StatelessWidget {
  const _FeedbackInvalido({
    required this.animacion,
    required this.game,
    required this.child,
  });

  final Animation<double> animacion;
  final GameTheme game;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, hijo) {
        final t = animacion.value;
        // A damped sine: a couple of quick swings that settle back to centre.
        final desplazamiento = math.sin(t * math.pi * 4) * 10 * (1 - t);
        return Transform.translate(
          offset: Offset(desplazamiento, 0),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              hijo!,
              if (t > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: game.invalidMoveFlash
                            .withValues(alpha: 0.25 * (1 - t)),
                        borderRadius:
                            BorderRadius.circular(AppRadii.cell),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: child,
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

/// The board: a tappable canvas that paints the whole grid in one pass.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoCelda = constraints.maxWidth / tablero.columnas;
        final altoCelda = constraints.maxHeight / tablero.filas;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (detalle) {
            final columna = (detalle.localPosition.dx / anchoCelda).floor();
            final fila = (detalle.localPosition.dy / altoCelda).floor();
            if (fila < 0 ||
                columna < 0 ||
                fila >= tablero.filas ||
                columna >= tablero.columnas) {
              return;
            }
            onTap(Posicion.en(fila: fila, columna: columna));
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: _TableroPainter(tablero: tablero, game: game),
          ),
        );
      },
    );
  }
}

/// Paints empty dots, walls and continuous bending arrow paths with arrowheads.
class _TableroPainter extends CustomPainter {
  _TableroPainter({required this.tablero, required this.game});

  final TableroUI tablero;
  final GameTheme game;

  @override
  void paint(Canvas canvas, Size size) {
    final anchoCelda = size.width / tablero.columnas;
    final altoCelda = size.height / tablero.filas;
    final lado = anchoCelda < altoCelda ? anchoCelda : altoCelda;
    // Thin, elegant lines: ~22% of the cell leaves clear dark gaps between
    // parallel paths instead of the chunky near-full-cell stroke.
    final grosor = lado * 0.22;

    // Plain dark backdrop — no per-cell tiles.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = game.boardBackground,
    );

    Offset centro(Posicion p) => Offset(
          (p.columna + 0.5) * anchoCelda,
          (p.fila + 0.5) * altoCelda,
        );

    for (final celda in tablero.celdas) {
      final c = centro(celda.posicion);
      switch (celda.tipo) {
        case TipoCeldaUI.vacia:
          canvas.drawCircle(c, lado * 0.06, Paint()..color = game.emptyDot);
        case TipoCeldaUI.pared:
          final rect = Rect.fromCenter(
            center: c,
            width: lado * 0.7,
            height: lado * 0.7,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(lado * 0.18)),
            Paint()..color = game.cellWall,
          );
        case TipoCeldaUI.flecha:
          _pintarSegmento(canvas, celda, c, lado, grosor);
      }
    }
  }

  /// Draws one path segment as a continuous stroke toward each connected
  /// neighbour, plus the single arrowhead when this segment is the head.
  void _pintarSegmento(
    Canvas canvas,
    CeldaUI celda,
    Offset centro,
    double lado,
    double grosor,
  ) {
    final color = game.colorFlecha(celda.idFlecha!);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = grosor * 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final trazo = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // A stub from the centre toward each connected neighbour reaches the shared
    // cell edge, so adjacent segments meet into one continuous, bending line.
    final conexiones = celda.conexiones.isEmpty
        // A lone-cell path still needs a visible body nub.
        ? <Direccion>{Direccion.abajo}
        : celda.conexiones;
    for (final direccion in conexiones) {
      final extremo = centro +
          Offset(direccion.delta.x.toDouble(), direccion.delta.y.toDouble()) *
              (lado * 0.5);
      canvas.drawLine(centro, extremo, glow);
      canvas.drawLine(centro, extremo, trazo);
    }
    // Round the join at corners and endpoints.
    canvas.drawCircle(centro, grosor / 2, Paint()..color = color);

    if (celda.esCabeza && celda.direccion != null) {
      _pintarPuntaFlecha(canvas, centro, celda.direccion!, lado, color);
    }
  }

  /// Draws a filled triangular arrowhead at [centro] pointing in [direccion].
  void _pintarPuntaFlecha(
    Canvas canvas,
    Offset centro,
    Direccion direccion,
    double lado,
    Color color,
  ) {
    final dir = Offset(
      direccion.delta.x.toDouble(),
      direccion.delta.y.toDouble(),
    );
    final perp = Offset(-dir.dy, dir.dx);
    final punta = centro + dir * (lado * 0.34);
    final base = centro + dir * (lado * 0.04);
    final izquierda = base + perp * (lado * 0.17);
    final derecha = base - perp * (lado * 0.17);

    final camino = Path()
      ..moveTo(punta.dx, punta.dy)
      ..lineTo(izquierda.dx, izquierda.dy)
      ..lineTo(derecha.dx, derecha.dy)
      ..close();
    canvas.drawPath(camino, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TableroPainter old) =>
      !identical(old.tablero, tablero) || old.game != game;
}
