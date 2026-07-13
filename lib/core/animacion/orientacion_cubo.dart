import 'dart:math' as math;

import 'punto2d.dart';
import 'punto3d.dart';

/// A [Punto3D] already projected to screen space: its [pantalla] position and
/// [escala] (how much bigger/smaller than a base cell it should draw — nearer
/// cells scale up, farther ones scale down), plus the raw rotated
/// [profundidad] for depth-sorting draw order.
class PuntoProyectado {
  /// Creates a projected point.
  const PuntoProyectado({
    required this.pantalla,
    required this.escala,
    required this.profundidad,
  });

  /// The 2D screen-space position, in the same cell-unit space [pantalla]
  /// callers scale to pixels.
  final Punto2D pantalla;

  /// The draw scale for this point: `1.0` at the orientation's origin plane,
  /// greater for points rotated toward the camera, smaller for points
  /// rotated away. Always positive.
  final double escala;

  /// The rotated depth (`z` after applying the orientation) — larger is
  /// closer to the camera. Used to depth-sort a set of points back-to-front
  /// before painting, so nearer cells occlude farther ones.
  final double profundidad;
}

/// The drag-driven rotation of the 3D board view — a yaw/pitch orbit around
/// the board's centre, plus the projection from rotated 3D cell coordinates
/// to a 2D screen point with a depth-based scale.
///
/// Pure Dart, no `dart:ui`/Flutter dependency (mirrors the arc-length path
/// sampler's pattern): the View owns the live orientation in widget state,
/// updates it from pan gestures via [rotada], and converts [proyectar]'s
/// [Punto2D] output to pixel `Offset`s when it paints.
class OrientacionCubo {
  /// Creates an orientation. Defaults to no rotation (looking straight at the
  /// board's front face).
  const OrientacionCubo({this.yaw = 0, this.pitch = 0});

  /// Rotation around the vertical (Y) axis, in radians.
  final double yaw;

  /// Rotation around the horizontal (X) axis, in radians.
  final double pitch;

  /// The maximum absolute [pitch]: clamped just short of a full quarter-turn
  /// so the camera never flips past looking straight down/up (which would
  /// invert the felt drag direction — a gimbal flip).
  static const double pitchMaximo = math.pi / 2 * 0.92;

  /// Returns a new orientation nudged by [dYaw]/[dPitch] (radians), as driven
  /// by one increment of a drag gesture. [yaw] accumulates without bound (an
  /// orbit wraps naturally through sin/cos); [pitch] is clamped to
  /// `[-pitchMaximo, pitchMaximo]`.
  OrientacionCubo rotada({required double dYaw, required double dPitch}) {
    return OrientacionCubo(
      yaw: yaw + dYaw,
      pitch: (pitch + dPitch).clamp(-pitchMaximo, pitchMaximo),
    );
  }

  /// Rotates [p] by this orientation: yaw around the Y axis first, then pitch
  /// around the (already-yawed) X axis.
  Punto3D aplicar(Punto3D p) {
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final x1 = p.x * cosY + p.z * sinY;
    final z1 = -p.x * sinY + p.z * cosY;

    final cosX = math.cos(pitch);
    final sinX = math.sin(pitch);
    final y2 = p.y * cosX - z1 * sinX;
    final z2 = p.y * sinX + z1 * cosX;

    return Punto3D(x1, y2, z2);
  }

  /// The floor [escala] can never drop below, so an arbitrarily distant point
  /// still draws at a small but visible, strictly positive size.
  static const double _escalaMinima = 0.15;

  /// Projects an already-rotated point [rotado] (see [aplicar]) to screen
  /// space. [factorProfundidad] controls how strongly depth affects scale —
  /// `escala = 1 + z * factorProfundidad`, clamped to stay positive.
  PuntoProyectado proyectar(Punto3D rotado, {double factorProfundidad = 0.35}) {
    final escala =
        math.max(_escalaMinima, 1 + rotado.z * factorProfundidad);
    return PuntoProyectado(
      pantalla: Punto2D(rotado.x * escala, rotado.y * escala),
      escala: escala,
      profundidad: rotado.z,
    );
  }

  /// Convenience: rotates [p] by this orientation ([aplicar]) and projects
  /// the result ([proyectar]) in one call.
  PuntoProyectado proyectarPunto(Punto3D p, {double factorProfundidad = 0.35}) =>
      proyectar(aplicar(p), factorProfundidad: factorProfundidad);
}
