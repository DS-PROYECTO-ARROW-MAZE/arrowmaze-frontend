import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
  const GameView({
    required this.viewModel,
    this.construirRanking,
    this.onReintentar,
    this.onSiguiente,
    this.onMenu,
    super.key,
  });

  /// The view model this screen renders and forwards taps to.
  final JuegoViewModel viewModel;

  /// Builds the leaderboard screen to push when the app-bar trophy is tapped.
  /// When `null` the leaderboard action is hidden. Injected by the composition
  /// root so this View never references the DI graph.
  final WidgetBuilder? construirRanking;

  /// Replays the current level. Shown on both end-of-game overlays.
  final VoidCallback? onReintentar;

  /// Advances to the next level. When `null` (no next level), the "Next" button
  /// is hidden — e.g. on the last level or after a defeat.
  final VoidCallback? onSiguiente;

  /// Returns to the Level Selection menu. Shown on both end-of-game overlays.
  final VoidCallback? onMenu;

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
      appBar: AppBar(
        title: const Text('ArrowMaze'),
        actions: [
          // Leaderboard is always reachable, even after the level is decided.
          if (widget.construirRanking != null)
            IconButton(
              icon: const Icon(Icons.leaderboard_outlined),
              tooltip: 'Leaderboard',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: widget.construirRanking!),
              ),
            ),
          // Audio mute toggle — always visible in the app bar.
          IconButton(
            icon: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                final muted = widget.viewModel.estado.muted;
                return Icon(
                  muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                );
              },
            ),
            tooltip: 'Toggle sound',
            onPressed: widget.viewModel.toggleMute,
          ),
          ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              final estado = widget.viewModel.estado;
              // The play controls are hidden once the level is decided.
              if (estado.victoria != null || estado.derrota) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Undo the last move; disabled when there is nothing to undo.
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Undo',
                    onPressed: widget.viewModel.puedeDeshacer
                        ? widget.viewModel.deshacer
                        : null,
                  ),
                  IconButton(
                    icon: Icon(estado.pausado ? Icons.play_arrow : Icons.pause),
                    tooltip: estado.pausado ? 'Resume' : 'Pause',
                    onPressed: estado.pausado
                        ? widget.viewModel.reanudar
                        : widget.viewModel.pausar,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final estado = widget.viewModel.estado;
          return Stack(
            children: [
              Column(
                children: [
                  _Hud(
                    movimientos: estado.movimientos,
                    coleccionables: estado.coleccionables,
                    tiempoRestante: estado.tiempoRestante,
                    game: game,
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: AspectRatio(
                          aspectRatio:
                              estado.tablero.columnas / estado.tablero.filas,
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
              ),
              // Session-state overlays (DM-F8): each reads only the UI snapshot,
              // never the domain `EstadoSesion`.
              if (estado.pausado)
                _PausaOverlay(onReanudar: widget.viewModel.reanudar),
              if (estado.victoria != null)
                _VictoriaOverlay(
                  game: game,
                  victoria: estado.victoria!,
                  onReintentar: widget.onReintentar,
                  onSiguiente: widget.onSiguiente,
                  onMenu: widget.onMenu,
                ),
              if (estado.derrota)
                _DerrotaOverlay(
                  game: game,
                  onReintentar: widget.onReintentar,
                  onMenu: widget.onMenu,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A full-screen scrim hosting an end-of-session or pause panel. Purely
/// presentational — built entirely from theme tokens.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.background.withValues(alpha: 0.82),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while the session is paused; its button resumes play.
class _PausaOverlay extends StatelessWidget {
  const _PausaOverlay({required this.onReanudar});

  final VoidCallback onReanudar;

  @override
  Widget build(BuildContext context) {
    return _Overlay(
      children: [
        const Text('Paused', style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: onReanudar,
          child: const Text('Resume'),
        ),
      ],
    );
  }
}

/// Shown when the board is cleared — the victory snapshot (UI), distinct from the
/// domain `EstadoVictoria`.
class _VictoriaOverlay extends StatelessWidget {
  const _VictoriaOverlay({
    required this.game,
    required this.victoria,
    this.onReintentar,
    this.onSiguiente,
    this.onMenu,
  });

  final GameTheme game;
  final VictoriaViewState victoria;
  final VoidCallback? onReintentar;
  final VoidCallback? onSiguiente;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return _Overlay(
      children: [
        _Estrellas(estrellas: victoria.estrellas, game: game),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Victory!',
          style: AppTypography.titleLarge.copyWith(color: game.validMoveFlash),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${victoria.puntaje}',
          style: AppTypography.displayLarge.copyWith(
            color: game.scoreColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Cleared in ${victoria.movimientos} moves',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        _AccionesFinDeJuego(
          onReintentar: onReintentar,
          onSiguiente: onSiguiente,
          onMenu: onMenu,
        ),
      ],
    );
  }
}

/// One to three filled stars (and the rest as hollow slots) that reflect the
/// player's star rating. Uses [GameTheme.starActive]/[starInactive] tokens.
class _Estrellas extends StatelessWidget {
  const _Estrellas({required this.estrellas, required this.game});

  final int estrellas;
  final GameTheme game;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final activa = i < estrellas;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Icon(
            Icons.star_rounded,
            size: 48,
            color: activa ? game.starActive : game.starInactive,
          ),
        );
      }),
    );
  }
}

/// Shown when a timed level's clock runs out — the defeat snapshot (UI),
/// distinct from the domain `EstadoDerrota`.
class _DerrotaOverlay extends StatelessWidget {
  const _DerrotaOverlay({
    required this.game,
    this.onReintentar,
    this.onMenu,
  });

  final GameTheme game;
  final VoidCallback? onReintentar;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return _Overlay(
      children: [
        Icon(Icons.timer_off, color: game.invalidMoveFlash, size: 64),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Time\'s up',
          style: AppTypography.titleLarge.copyWith(color: game.invalidMoveFlash),
        ),
        const SizedBox(height: AppSpacing.xl),
        // No "Next" after a defeat — only retry the same level or leave.
        _AccionesFinDeJuego(
          onReintentar: onReintentar,
          onMenu: onMenu,
        ),
      ],
    );
  }
}

/// The shared action row for the end-of-game overlays: optional **Next Level**,
/// **Retry**, and **Level Select**. Buttons whose callback is `null` are hidden.
class _AccionesFinDeJuego extends StatelessWidget {
  const _AccionesFinDeJuego({
    this.onReintentar,
    this.onSiguiente,
    this.onMenu,
  });

  final VoidCallback? onReintentar;
  final VoidCallback? onSiguiente;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSiguiente != null)
          FilledButton.icon(
            onPressed: onSiguiente,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next Level'),
          ),
        if (onSiguiente != null) const SizedBox(height: AppSpacing.sm),
        if (onReintentar != null)
          OutlinedButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        if (onReintentar != null) const SizedBox(height: AppSpacing.sm),
        if (onMenu != null)
          TextButton.icon(
            onPressed: onMenu,
            icon: const Icon(Icons.list),
            label: const Text('Level Select'),
          ),
      ],
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

/// The moves counter strip, plus a countdown clock on timed levels and a tally
/// of the collectibles picked up for bonus time.
class _Hud extends StatelessWidget {
  const _Hud({
    required this.movimientos,
    required this.coleccionables,
    required this.game,
    this.tiempoRestante,
  });

  final int movimientos;
  final int coleccionables;
  final GameTheme game;
  final Duration? tiempoRestante;

  /// Formats the remaining time as `m:ss` for the HUD clock.
  String _formatear(Duration d) {
    final minutos = d.inMinutes;
    final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Moves: ', style: AppTypography.bodyMedium),
          Text('$movimientos', style: AppTypography.hudNumber),
          if (tiempoRestante != null) ...[
            const SizedBox(width: AppSpacing.xl),
            const Icon(Icons.timer_outlined, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(_formatear(tiempoRestante!), style: AppTypography.hudNumber),
          ],
          // The bonus tally only appears once something has been collected.
          if (coleccionables > 0) ...[
            const SizedBox(width: AppSpacing.xl),
            Icon(Icons.diamond_outlined, size: 18, color: game.cellCollectible),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$coleccionables',
              style: AppTypography.hudNumber.copyWith(color: game.cellCollectible),
            ),
          ],
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
        case TipoCeldaUI.ausente:
          break; // Outside the playable region — draw nothing.
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
        case TipoCeldaUI.coleccionable:
          _pintarColeccionable(canvas, c, lado);
        case TipoCeldaUI.flecha:
          _pintarSegmento(canvas, celda, c, lado, grosor);
      }
    }
  }

  /// Draws a collectible as a glowing diamond — transparent to rays, so it sits
  /// lightly over the dark board the way an empty dot does, but bright and
  /// bonus-coloured.
  void _pintarColeccionable(Canvas canvas, Offset centro, double lado) {
    final radio = lado * 0.2;
    final rombo = Path()
      ..moveTo(centro.dx, centro.dy - radio)
      ..lineTo(centro.dx + radio, centro.dy)
      ..lineTo(centro.dx, centro.dy + radio)
      ..lineTo(centro.dx - radio, centro.dy)
      ..close();

    final glow = Paint()
      ..color = game.collectibleGlow.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(rombo, glow);
    canvas.drawPath(rombo, Paint()..color = game.cellCollectible);
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
