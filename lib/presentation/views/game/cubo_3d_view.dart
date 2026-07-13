import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/animacion/orientacion_cubo.dart';
import '../../../core/animacion/punto3d.dart';
import '../../../core/i18n/cadenas_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/game_theme.dart';
import '../../../domain/value_objects/direccion.dart';
import '../../../domain/value_objects/posicion.dart';
import '../../viewmodels/juego_view_state.dart';
import 'pintura_flecha.dart';

/// The rotatable 3D cube view for a depth-aware board (ticket 36) — every
/// layer rendered at once in true 3D space, dragged to orbit, tapped to
/// resolve whichever visible path segment sits under the tap point.
///
/// Deliberately a **separate** widget/painter from the flat 2D board
/// (`_TableroPainter` in `game_view.dart`), not a unification of the two: the
/// flat path stays completely untouched (zero risk to real, well-tested 2D
/// levels), and the two share only the small pure arrowhead-triangle helper
/// ([pintarPuntaFlecha]).
///
/// The same visual language as the flat board — glowing path lines,
/// arrowheads, dots for empty cells, wall squares, collectible diamonds — is
/// reused here, just positioned by projecting each cell's `(fila, columna,
/// capa)` through an [OrientacionCubo] instead of a flat grid.
class Cubo3D extends StatefulWidget {
  /// Creates the cube view over [tablero] (every layer, not one slice), using
  /// [game]'s tokens, calling [onTap] with the exact [Posicion] of whichever
  /// playable cell a tap-without-drag resolves to.
  ///
  /// [orientacionInicial] is a testing seam (production leaves it at the
  /// default "hero" angle); it is the orientation the cube starts at.
  const Cubo3D({
    required this.tablero,
    required this.game,
    required this.onTap,
    this.orientacionInicial = const OrientacionCubo(yaw: -0.6, pitch: -0.35),
    super.key,
  });

  /// The whole-board snapshot (every layer) to render.
  final TableroUI tablero;

  /// Game theme tokens — the exact same ones the flat board paints with.
  final GameTheme game;

  /// Invoked with the resolved cell's position when a tap (not a drag)
  /// lands on a playable, visible cell.
  final void Function(Posicion posicion) onTap;

  /// The orientation the cube starts at.
  final OrientacionCubo orientacionInicial;

  @override
  State<Cubo3D> createState() => _Cubo3DState();
}

class _Cubo3DState extends State<Cubo3D> {
  /// Radians of yaw/pitch per logical pixel of drag.
  static const double _sensibilidad = 0.01;

  /// Below this total drag distance (logical pixels), a pan gesture is
  /// treated as a tap instead of a rotation.
  static const double _umbralToque = 8.0;

  late OrientacionCubo _orientacion = widget.orientacionInicial;

  Offset? _panPosicionActual;
  double _panDistanciaAcumulada = 0;

  void _alIniciarPan(DragStartDetails detalles) {
    _panPosicionActual = detalles.localPosition;
    _panDistanciaAcumulada = 0;
  }

  void _alActualizarPan(DragUpdateDetails detalles) {
    _panPosicionActual = detalles.localPosition;
    _panDistanciaAcumulada += detalles.delta.distance;
    setState(() {
      _orientacion = _orientacion.rotada(
        dYaw: detalles.delta.dx * _sensibilidad,
        dPitch: -detalles.delta.dy * _sensibilidad,
      );
    });
  }

  void _alTerminarPan(Size tamano) {
    final posicion = _panPosicionActual;
    _panPosicionActual = null;
    if (posicion == null || _panDistanciaAcumulada >= _umbralToque) return;
    _resolverToque(posicion, tamano);
  }

  /// Resolves [posicionLocal] against the same projection [_CuboPainter]
  /// paints with, picking the **frontmost** (largest scale) playable cell
  /// whose projected hit radius contains the tap.
  void _resolverToque(Offset posicionLocal, Size tamano) {
    _CeldaProyectada? mejor;
    for (final p in _proyectarCeldas(widget.tablero, _orientacion, tamano)) {
      if (!p.celda.esJugable) continue;
      final radio = _ladoBase(widget.tablero, tamano) * p.escala * 0.5;
      if ((p.centro - posicionLocal).distance > radio) continue;
      if (mejor == null || p.escala > mejor.escala) mejor = p;
    }
    if (mejor != null) widget.onTap(mejor.celda.posicion);
  }

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tamano = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _alIniciarPan,
          onPanUpdate: _alActualizarPan,
          onPanEnd: (_) => _alTerminarPan(tamano),
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _CuboPainter(
                  tablero: widget.tablero,
                  orientacion: _orientacion,
                  game: widget.game,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.sm,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      s.arrastrarParaRotar,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
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

/// The cube-centred coordinate of [posicion] on [tablero]: `(0,0,0)` sits at
/// the board's geometric centre, so the whole shape rotates in place.
Punto3D _puntoCubo(Posicion posicion, TableroUI tablero) {
  return Punto3D(
    posicion.columna - (tablero.columnas - 1) / 2,
    posicion.fila - (tablero.filas - 1) / 2,
    posicion.capa - (tablero.profundo - 1) / 2,
  );
}

/// Pixels-per-cell-unit scale that fits the whole cube inside [tamano] at
/// **any** rotation: sized from the cube's bounding-sphere radius, not just
/// its resting footprint, so a diagonal orientation never clips.
double _escalaPixel(TableroUI tablero, Size tamano) {
  final radioCubo = 0.5 *
      math.sqrt(
        tablero.filas * tablero.filas +
            tablero.columnas * tablero.columnas +
            tablero.profundo * tablero.profundo,
      );
  final lado = math.min(tamano.width, tamano.height);
  return radioCubo == 0 ? lado : (lado * 0.42) / radioCubo;
}

/// The baseline on-screen cell size (before a specific cell's depth scale is
/// applied) — a fraction of one grid unit, leaving visible gaps between
/// adjacent cells, matching the flat board's proportions.
double _ladoBase(TableroUI tablero, Size tamano) =>
    _escalaPixel(tablero, tamano) * 0.8;

/// One [CeldaUI] already projected to screen space for a single paint/hit-test
/// pass: its pixel [centro], depth [escala] and rotated [profundidad] (for
/// depth-sort order).
class _CeldaProyectada {
  const _CeldaProyectada({
    required this.celda,
    required this.centro,
    required this.escala,
    required this.profundidad,
  });

  final CeldaUI celda;
  final Offset centro;
  final double escala;
  final double profundidad;
}

/// Projects every cell of [tablero] through [orientacion] into [tamano]'s
/// pixel space. The **single** pure function both the painter and the tap
/// hit-test use, so they can never drift out of sync with each other.
List<_CeldaProyectada> _proyectarCeldas(
  TableroUI tablero,
  OrientacionCubo orientacion,
  Size tamano,
) {
  final escalaPixel = _escalaPixel(tablero, tamano);
  final centroPantalla = Offset(tamano.width / 2, tamano.height / 2);
  return tablero.celdas.map((celda) {
    final proyectado =
        orientacion.proyectarPunto(_puntoCubo(celda.posicion, tablero));
    final centro = centroPantalla +
        Offset(
          proyectado.pantalla.x * escalaPixel,
          proyectado.pantalla.y * escalaPixel,
        );
    return _CeldaProyectada(
      celda: celda,
      centro: centro,
      escala: proyectado.escala,
      profundidad: proyectado.profundidad,
    );
  }).toList();
}

/// The normalized on-screen direction from [origen] toward
/// `origen.desplazar(direccion)`, after rotating both by [orientacion] —
/// what a path's connection stub or arrowhead actually points along once the
/// cube is rotated (a raw domain [Direccion] no longer points the same way on
/// screen once the cube has been dragged).
Offset _direccionPantalla(
  Posicion origen,
  Direccion direccion,
  TableroUI tablero,
  OrientacionCubo orientacion,
) {
  final desde = orientacion.aplicar(_puntoCubo(origen, tablero));
  final hacia = orientacion
      .aplicar(_puntoCubo(origen.desplazar(direccion), tablero));
  final dx = hacia.x - desde.x;
  final dy = hacia.y - desde.y;
  final longitud = math.sqrt(dx * dx + dy * dy);
  // Degenerate only when the step points straight along the current view
  // axis (on screen it would be a dot, not a line) — an arbitrary but stable
  // direction keeps the arrowhead/stub from disappearing entirely.
  return longitud == 0 ? const Offset(0, 1) : Offset(dx / longitud, dy / longitud);
}

/// Paints every cell of the cube, depth-sorted back-to-front so nearer cells
/// occlude farther ones — which is exactly what makes an absent outer-shell
/// cell read as a **hole**: it is simply never drawn, so whatever was already
/// painted behind it stays visible.
class _CuboPainter extends CustomPainter {
  _CuboPainter({
    required this.tablero,
    required this.orientacion,
    required this.game,
  });

  final TableroUI tablero;
  final OrientacionCubo orientacion;
  final GameTheme game;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = game.boardBackground);

    final proyectadas = _proyectarCeldas(tablero, orientacion, size)
      ..sort((a, b) => a.profundidad.compareTo(b.profundidad));
    final porPosicion = {for (final p in proyectadas) p.celda.posicion: p};
    final lado = _ladoBase(tablero, size);

    for (final p in proyectadas) {
      final celda = p.celda;
      final ladoCelda = lado * p.escala;
      switch (celda.tipo) {
        case TipoCeldaUI.ausente:
          break; // A hole in the shell — draw nothing.
        case TipoCeldaUI.vacia:
          canvas.drawCircle(p.centro, ladoCelda * 0.08, Paint()..color = game.emptyDot);
        case TipoCeldaUI.pared:
          final rect = Rect.fromCenter(
            center: p.centro,
            width: ladoCelda * 0.7,
            height: ladoCelda * 0.7,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(ladoCelda * 0.18)),
            Paint()..color = game.cellWall,
          );
        case TipoCeldaUI.coleccionable:
          _pintarColeccionable(canvas, p.centro, ladoCelda);
        case TipoCeldaUI.flecha:
          _pintarSegmento(canvas, p, ladoCelda, porPosicion);
      }
    }
  }

  /// Draws a collectible as a glowing diamond, same recipe as the flat board.
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

  /// Draws one path segment: a stub toward each connected neighbour's
  /// projected centre (so a depth-bending path's line still meets its
  /// neighbours edge-to-edge on screen), plus the single arrowhead when this
  /// segment is the head.
  void _pintarSegmento(
    Canvas canvas,
    _CeldaProyectada p,
    double lado,
    Map<Posicion, _CeldaProyectada> porPosicion,
  ) {
    final celda = p.celda;
    final color = game.colorFlecha(celda.idFlecha!);
    final grosor = lado * 0.22;

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

    if (celda.conexiones.isEmpty) {
      // A lone-cell path still needs a visible body nub.
      final extremo = p.centro + const Offset(0, 1) * (lado * 0.35);
      canvas.drawLine(p.centro, extremo, glow);
      canvas.drawLine(p.centro, extremo, trazo);
    } else {
      for (final direccion in celda.conexiones) {
        final vecino = porPosicion[celda.posicion.desplazar(direccion)];
        if (vecino == null) continue; // Defensive: a connected path always has one.
        final medio = Offset.lerp(p.centro, vecino.centro, 0.5)!;
        canvas.drawLine(p.centro, medio, glow);
        canvas.drawLine(p.centro, medio, trazo);
      }
    }
    canvas.drawCircle(p.centro, grosor / 2, Paint()..color = color);

    if (celda.esCabeza && celda.direccion != null) {
      final direccionPantalla =
          _direccionPantalla(celda.posicion, celda.direccion!, tablero, orientacion);
      pintarPuntaFlecha(canvas, p.centro, direccionPantalla, lado, color);
    }
  }

  @override
  bool shouldRepaint(covariant _CuboPainter old) =>
      !identical(old.tablero, tablero) ||
      old.orientacion.yaw != orientacion.yaw ||
      old.orientacion.pitch != orientacion.pitch ||
      old.game != game;
}
