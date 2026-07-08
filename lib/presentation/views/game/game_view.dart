import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/animacion/muestreador_trayectoria.dart';
import '../../../core/animacion/punto2d.dart';
import '../../../core/i18n/cadenas_scope.dart';
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
/// `AppSpacing`, `AppRadii`), never hard-coded here. Every user-facing string is
/// read from [CadenasScope] — no literals in this View (AC3).
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

class _GameViewState extends State<GameView> with TickerProviderStateMixin {
  /// Drives the invalid-tap shake/flash; one short pulse per penalized move.
  late final AnimationController _feedback;

  /// The exit animations currently playing — one per arrow leaving the board.
  /// Multiple may run at once (concurrent exits, AC4); each is removed and its
  /// controller disposed when it finishes.
  final List<_SalidaEnCurso> _salidas = <_SalidaEnCurso>[];

  /// Guards against launching the same transient descriptor twice: the last
  /// descriptor instance already turned into a running animation.
  AnimacionSalida? _ultimaSalidaProcesada;

  @override
  void initState() {
    super.initState();
    _feedback = AnimationController(vsync: this, duration: AppDurations.fast);
    widget.viewModel.addListener(_alCambiarEstado);
  }

  /// Reacts to every published state: fires the invalid-tap feedback pulse and
  /// launches a snake-gait exit animation when a fresh descriptor appears. The
  /// board itself is never mutated here — only the transient affordances.
  void _alCambiarEstado() {
    final estado = widget.viewModel.estado;
    if (estado.alertaInvalida) {
      _feedback.forward(from: 0);
    }
    final salida = estado.animacionSalida;
    if (salida != null && !identical(salida, _ultimaSalidaProcesada)) {
      _ultimaSalidaProcesada = salida;
      _lanzarSalida(salida);
    }
  }

  /// Starts one exit animation for [salida], driving a normalized `t` from 0→1
  /// that the painter samples along the arrow's own polyline.
  void _lanzarSalida(AnimacionSalida salida) {
    final controlador = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );
    final tablero = widget.viewModel.estado.tablero;
    final enCurso = _SalidaEnCurso(
      idFlecha: salida.idFlecha,
      controlador: controlador,
      muestreador: _construirMuestreador(salida),
      cantidad: salida.segmentos.length,
      direccion: salida.direccionSalida,
      filas: tablero.filas,
      columnas: tablero.columnas,
    );
    controlador.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      // Once finished, drop the overlay and free the controller. The `mounted`
      // guard covers the screen closing mid-exit — there, dispose() already
      // released every in-flight controller, so this listener never fires late.
      if (mounted) setState(() => _salidas.remove(enCurso));
      controlador.dispose();
    });
    setState(() => _salidas.add(enCurso));
    controlador.forward();
  }

  /// Builds the arc-length sampler for [salida]: the exiting cell centres
  /// (tail → head) in cell units, extended straight past the head toward the
  /// off-board edge target with enough runway for the whole body to clear.
  MuestreadorTrayectoria _construirMuestreador(AnimacionSalida salida) {
    Punto2D centro(Posicion p) => Punto2D(p.columna + 0.5, p.fila + 0.5);

    final puntos = salida.segmentos.map(centro).toList();
    final cabeza = salida.segmentos.last;
    final paso = salida.direccionSalida.delta;
    // Steps from the head to the board-edge target, then a full body-length of
    // extra runway so at t = 1 even the tail has slid off the board.
    final distanciaBorde = (salida.objetivoBorde.columna - cabeza.columna) *
            paso.x +
        (salida.objetivoBorde.fila - cabeza.fila) * paso.y;
    final pasosExtra = distanciaBorde + salida.segmentos.length;
    for (var k = 1; k <= pasosExtra; k++) {
      puntos.add(centro(Posicion.en(
        fila: cabeza.fila + paso.y * k,
        columna: cabeza.columna + paso.x * k,
      )));
    }
    return MuestreadorTrayectoria(puntos);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_alCambiarEstado);
    _feedback.dispose();
    for (final salida in _salidas) {
      salida.controlador.dispose();
    }
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);
    final game = Theme.of(context).extension<GameTheme>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.pantallaJuego),
        actions: [
          // Leaderboard is always reachable, even after the level is decided.
          if (widget.construirRanking != null)
            IconButton(
              icon: const Icon(Icons.leaderboard_outlined),
              tooltip: s.tableroDeClasificacion,
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
            tooltip: s.alternarSonido,
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
                  // Undo the last move; disabled when cap is exhausted or there
                  // is nothing to undo.
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: estado.usosUndoRestantes > 0
                        ? s.deshacerConUsos(estado.usosUndoRestantes)
                        : s.deshacer,
                    onPressed: widget.viewModel.puedeDeshacer
                        ? widget.viewModel.deshacer
                        : null,
                  ),
                  IconButton(
                    icon: Icon(estado.pausado ? Icons.play_arrow : Icons.pause),
                    tooltip: estado.pausado ? s.reanudar : s.pausar,
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
                    movimientos: estado.movimientosRestantes >= 0
                        ? estado.movimientosRestantes
                        : estado.movimientos,
                    esCountdown: estado.movimientosRestantes >= 0,
                    coleccionables: estado.coleccionables,
                    tiempoRestante: estado.tiempoRestante,
                    avisoTiempo: estado.avisoTiempo,
                    usosUndoRestantes: estado.usosUndoRestantes,
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
                              salidas: _salidas,
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
                  derrotaPorTiempo: estado.derrotaPorTiempo,
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
    final s = CadenasScope.of(context);
    return _Overlay(
      children: [
        Text(s.pausado, style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: onReanudar,
          child: Text(s.reanudar),
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
    final s = CadenasScope.of(context);
    return _Overlay(
      children: [
        Text(
          s.victoria,
          style: AppTypography.titleLarge.copyWith(color: game.validMoveFlash),
        ),
        if (victoria.mostrarPuntuacion) ...[
          const SizedBox(height: AppSpacing.sm),
          _Estrellas(estrellas: victoria.estrellas, game: game),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${victoria.puntaje}',
            style: AppTypography.displayLarge.copyWith(
              color: game.scoreColor,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          s.limpiadoEn(victoria.movimientos),
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

/// Shown when the level is lost — the defeat snapshot (UI), distinct from the
/// domain `EstadoDerrota`. Shows different icon and message for timer timeout
/// vs. move exhaustion (Ticket 30).
class _DerrotaOverlay extends StatelessWidget {
  const _DerrotaOverlay({
    required this.game,
    required this.derrotaPorTiempo,
    this.onReintentar,
    this.onMenu,
  });

  final GameTheme game;
  final bool derrotaPorTiempo;
  final VoidCallback? onReintentar;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);
    return _Overlay(
      children: [
        Icon(
          derrotaPorTiempo ? Icons.timer_off : Icons.do_disturb_alt_outlined,
          color: game.invalidMoveFlash,
          size: 64,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          derrotaPorTiempo ? s.tiempoAgotado : s.movimientosAgotados,
          style:
              AppTypography.titleLarge.copyWith(color: game.invalidMoveFlash),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          derrotaPorTiempo ? s.sinTiempo : s.sinMovimientos,
          style: AppTypography.bodyMedium,
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
    final s = CadenasScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSiguiente != null)
          FilledButton.icon(
            onPressed: onSiguiente,
            icon: const Icon(Icons.arrow_forward),
            label: Text(s.siguienteNivel),
          ),
        if (onSiguiente != null) const SizedBox(height: AppSpacing.sm),
        if (onReintentar != null)
          OutlinedButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh),
            label: Text(s.reintentar),
          ),
        if (onReintentar != null) const SizedBox(height: AppSpacing.sm),
        if (onMenu != null)
          TextButton.icon(
            onPressed: onMenu,
            icon: const Icon(Icons.list),
            label: Text(s.seleccionNiveles),
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
///
/// The countdown clock shifts from neutral → warning → danger as the remaining
/// time drops below 30 and 10 seconds respectively, using [GameTheme] tokens
/// so the visual tuning stays in one place. In the final-warning window
/// ([avisoTiempo], ticket 29) the clock adopts a **distinct** style — a danger
/// colour and a steady pulse — so the player registers the heads-up at a glance.
class _Hud extends StatelessWidget {
  const _Hud({
    required this.movimientos,
    required this.esCountdown,
    required this.coleccionables,
    required this.game,
    this.tiempoRestante,
    this.avisoTiempo = false,
    this.usosUndoRestantes = 3,
  });

  /// Threshold at which the timer turns warning yellow (seconds).
  static const _avisoSegundos = 30;

  /// Threshold at which the timer turns danger red (seconds).
  static const _peligroSegundos = 10;

  final int movimientos;
  final bool esCountdown;
  final int coleccionables;
  final GameTheme game;
  final Duration? tiempoRestante;

  /// Whether the timed level is inside its final 15-second warning window: the
  /// clock then pulses in the danger colour (ticket 29, AC2).
  final bool avisoTiempo;
  final int usosUndoRestantes;

  /// Formats the remaining time as `m:ss` for the HUD clock.
  String _formatear(Duration d) {
    final minutos = d.inMinutes;
    final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  Color _timerColor(Duration restante) {
    if (restante.inSeconds <= _peligroSegundos) return game.invalidMoveFlash;
    if (restante.inSeconds <= _avisoSegundos) return game.starActive;
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);
    // In the final-warning window the clock takes the danger colour outright so
    // the pulsing cue reads as urgent, distinct from the steady 30 s/10 s tints.
    final timerColor = tiempoRestante == null
        ? null
        : (avisoTiempo ? game.invalidMoveFlash : _timerColor(tiempoRestante!));
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(s.etiquetaMovimientos, style: AppTypography.bodyMedium),
          Text('$movimientos', style: AppTypography.hudNumber),
          if (usosUndoRestantes < 3) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.undo, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$usosUndoRestantes',
              style: AppTypography.bodyMedium,
            ),
          ],
          if (tiempoRestante != null) ...[
            const SizedBox(width: AppSpacing.xl),
            _RelojHud(
              texto: _formatear(tiempoRestante!),
              color: timerColor!,
              aviso: avisoTiempo,
            ),
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

/// The HUD countdown clock: the timer icon and `m:ss` text, which **pulse** in
/// unison while [aviso] is set (the final 15 seconds, ticket 29, AC2).
///
/// The pulse is a purely presentational affordance driven by a repeating
/// controller; it carries no game logic. Outside the warning window it rests at
/// its natural size, so the distinct urgent look appears only when the ViewModel
/// says the run has crossed the threshold.
class _RelojHud extends StatefulWidget {
  const _RelojHud({
    required this.texto,
    required this.color,
    required this.aviso,
  });

  /// The formatted remaining time (`m:ss`).
  final String texto;

  /// The colour of the icon and text (danger colour while [aviso]).
  final Color color;

  /// Whether to play the final-warning pulse.
  final bool aviso;

  @override
  State<_RelojHud> createState() => _RelojHudState();
}

class _RelojHudState extends State<_RelojHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(vsync: this, duration: AppDurations.slow);
    _sincronizarPulso();
  }

  @override
  void didUpdateWidget(covariant _RelojHud anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.aviso != widget.aviso) _sincronizarPulso();
  }

  /// Runs the pulse only inside the warning window; otherwise it rests at its
  /// natural scale so the effect appears exactly when the warning is active.
  void _sincronizarPulso() {
    if (widget.aviso) {
      _pulso.repeat(reverse: true);
    } else {
      _pulso
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final escala = Tween<double>(begin: 1, end: 1.15).animate(
      CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
    );
    return ScaleTransition(
      scale: escala,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: widget.color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            widget.texto,
            style: AppTypography.hudNumber.copyWith(color: widget.color),
          ),
        ],
      ),
    );
  }
}

/// The board: a tappable canvas that paints the whole grid in one pass, with any
/// in-flight snake-gait exit animations overlaid on top of it.
class _Tablero extends StatelessWidget {
  const _Tablero({
    required this.estado,
    required this.game,
    required this.salidas,
    required this.onTap,
  });

  final JuegoViewState estado;
  final GameTheme game;

  /// The exit animations currently playing, drawn over the settled board so the
  /// arrow that already left the domain glides off visually.
  final List<_SalidaEnCurso> salidas;
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
            // Resolve the touch to a playable cell; taps off the board or on an
            // absent position (outside a shaped board) are ignored (AC4).
            final celda =
                tablero.celdaJugableEn(Posicion.en(fila: fila, columna: columna));
            if (celda == null) return;
            onTap(celda.posicion);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _TableroPainter(tablero: tablero, game: game),
              ),
              // One repainting overlay per exiting arrow; each samples its own
              // controller so concurrent exits animate independently.
              for (final salida in salidas)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: salida.controlador,
                    builder: (context, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _SalidaPainter(
                        salida: salida,
                        t: salida.controlador.value,
                        game: game,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One arrow's in-flight exit animation: its controller plus the pure sampler
/// that maps a normalized `t` onto the head and trailing body positions.
class _SalidaEnCurso {
  _SalidaEnCurso({
    required this.idFlecha,
    required this.controlador,
    required this.muestreador,
    required this.cantidad,
    required this.direccion,
    required this.filas,
    required this.columnas,
  });

  /// The id of the exiting path — selects its colour so the glide matches the
  /// arrow that was on the board.
  final int idFlecha;

  /// Drives the normalized progress `t` from 0 (settled) to 1 (fully off-board).
  final AnimationController controlador;

  /// The pure arc-length sampler for this arrow's exit polyline.
  final MuestreadorTrayectoria muestreador;

  /// How many body segments the snake has (its cell count).
  final int cantidad;

  /// The direction the head points as it leaves — where the arrowhead aims.
  final Direccion direccion;

  /// The board's row count, used to scale cell units to pixels so the overlay
  /// lines up with the settled board beneath it.
  final int filas;

  /// The board's column count (see [filas]).
  final int columnas;
}

/// Paints one exiting arrow as a continuous, bending snake: the sampled segment
/// centres are stroked into a single glowing line with an arrowhead at the head.
///
/// It is deliberately *dumb* — it consumes points sampled by
/// [MuestreadorTrayectoria] and never computes any path geometry itself, so the
/// gait (and its correctness through bends) lives entirely in the pure sampler.
class _SalidaPainter extends CustomPainter {
  _SalidaPainter({
    required this.salida,
    required this.t,
    required this.game,
  });

  final _SalidaEnCurso salida;
  final double t;
  final GameTheme game;

  @override
  void paint(Canvas canvas, Size size) {
    final puntos = salida.muestreador.posicionesSegmentos(
      t: t,
      cantidad: salida.cantidad,
    );
    if (puntos.isEmpty) return;

    // Cell units already carry the +0.5 centre offset, so scaling by the cell
    // size lands exactly where the board painter draws its cells.
    final anchoC = size.width / salida.columnas;
    final altoC = size.height / salida.filas;
    Offset aPixel(Punto2D p) => Offset(p.x * anchoC, p.y * altoC);
    final lado = anchoC < altoC ? anchoC : altoC;
    final grosor = lado * 0.22;
    final color = game.colorFlecha(salida.idFlecha);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = grosor * 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final trazo = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final camino = Path()..moveTo(aPixel(puntos.last).dx, aPixel(puntos.last).dy);
    for (var i = puntos.length - 2; i >= 0; i--) {
      camino.lineTo(aPixel(puntos[i]).dx, aPixel(puntos[i]).dy);
    }
    canvas.drawPath(camino, glow);
    canvas.drawPath(camino, trazo);

    // Arrowhead at the head (first sampled point), aiming along the exit.
    _pintarPunta(canvas, aPixel(puntos.first), salida.direccion, lado, color);
  }

  /// Draws a filled triangular arrowhead at [centro] pointing in [direccion].
  void _pintarPunta(
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
  bool shouldRepaint(covariant _SalidaPainter old) =>
      old.t != t || !identical(old.salida, salida) || old.game != game;
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
