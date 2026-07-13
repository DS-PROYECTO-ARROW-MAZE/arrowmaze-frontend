import 'package:flutter/material.dart';

/// Draws a filled triangular arrowhead at [centro] pointing along the
/// already-resolved, normalized on-screen unit vector [direccionPantalla],
/// sized relative to [lado].
///
/// Shared between the flat 2D board painter (`_TableroPainter`/
/// `_SalidaPainter` in `game_view.dart`) and the 3D cube painter
/// (`_CuboPainter` in `cubo_3d_view.dart`): a raw domain `Direccion` only
/// ever points the same way on screen for the flat, unrotated board — the
/// cube resolves its own screen-space direction first (accounting for the
/// current rotation) and calls this with the result.
void pintarPuntaFlecha(
  Canvas canvas,
  Offset centro,
  Offset direccionPantalla,
  double lado,
  Color color,
) {
  final perp = Offset(-direccionPantalla.dy, direccionPantalla.dx);
  final punta = centro + direccionPantalla * (lado * 0.34);
  final base = centro + direccionPantalla * (lado * 0.04);
  final izquierda = base + perp * (lado * 0.17);
  final derecha = base - perp * (lado * 0.17);
  final camino = Path()
    ..moveTo(punta.dx, punta.dy)
    ..lineTo(izquierda.dx, izquierda.dy)
    ..lineTo(derecha.dx, derecha.dy)
    ..close();
  canvas.drawPath(camino, Paint()..color = color);
}
