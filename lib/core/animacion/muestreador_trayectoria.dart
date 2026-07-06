import 'dart:math' as math;

import 'punto2d.dart';

/// Arc-length sampler for a bending polyline — the pure geometry behind the
/// **snake-gait exit animation** (ticket 22).
///
/// Given the ordered polyline an arrow follows out of the board (its own cell
/// centres, extended straight past the head to an off-board edge target), this
/// samples the position of the head and each trailing body segment so they all
/// ride the **same curve**, spaced a fixed arc-length apart. Because consecutive
/// board cells are one unit apart, a spacing of `1.0` places each tail exactly
/// one cell behind the segment ahead — through 90° bends and all, never a rigid
/// whole-shape translation.
///
/// Pure Dart, no business logic and no `dart:ui`: it works in cell units on
/// [Punto2D]s, and the View scales the sampled points to pixels when painting.
class MuestreadorTrayectoria {
  /// Wraps the ordered [polilinea] (tail → head → edge target). Requires at
  /// least two points so it has a direction to sample along.
  MuestreadorTrayectoria(this.polilinea)
      : assert(polilinea.length >= 2, 'A polyline needs at least two points'),
        _acumulado = _longitudesAcumuladas(polilinea);

  /// The polyline the snake rides, from tail through head to the edge target.
  final List<Punto2D> polilinea;

  /// Cumulative arc-length at each vertex; `_acumulado.last` is the total length.
  final List<double> _acumulado;

  /// The total arc-length of the polyline (its extent, in cell units).
  double get longitud => _acumulado.last;

  /// The centres of [cantidad] snake segments whose head sits at arc-length
  /// [longitudCabeza], each trailing segment [separacion] (default one cell)
  /// behind the one ahead, all sampled along the same curve.
  ///
  /// Index 0 is the head; index `i` sits at `longitudCabeza - i * separacion`,
  /// clamped to the polyline extent. This is what makes the tail follow the
  /// identical bending path rather than sliding rigidly.
  List<Punto2D> segmentosDesde({
    required double longitudCabeza,
    required int cantidad,
    double separacion = 1.0,
  }) {
    return List<Punto2D>.generate(
      cantidad,
      (i) => _puntoEnLongitud(longitudCabeza - i * separacion),
    );
  }

  /// The centres of [cantidad] snake segments at normalized progress [t] in
  /// `[0, 1]`.
  ///
  /// At `t = 0` the head rests on its starting cell (arc-length `cantidad - 1`,
  /// the last body cell); at `t = 1` it has advanced to the polyline's end — the
  /// off-board edge target — carrying the whole body off the board behind it.
  List<Punto2D> posicionesSegmentos({
    required double t,
    required int cantidad,
    double separacion = 1.0,
  }) {
    final inicioCabeza = (cantidad - 1) * separacion;
    final longitudCabeza = inicioCabeza + t * (longitud - inicioCabeza);
    return segmentosDesde(
      longitudCabeza: longitudCabeza,
      cantidad: cantidad,
      separacion: separacion,
    );
  }

  /// The point at arc-length [distancia] from the start, clamped to
  /// `[0, longitud]`, linearly interpolated within the containing segment.
  Punto2D _puntoEnLongitud(double distancia) {
    if (distancia <= 0) return polilinea.first;
    if (distancia >= longitud) return polilinea.last;

    // Find the segment [i, i+1] whose cumulative range contains `distancia`.
    var i = 0;
    while (i < _acumulado.length - 1 && _acumulado[i + 1] < distancia) {
      i++;
    }
    final tramo = _acumulado[i + 1] - _acumulado[i];
    final fraccion = tramo == 0 ? 0.0 : (distancia - _acumulado[i]) / tramo;
    return polilinea[i].interpolarHacia(polilinea[i + 1], fraccion);
  }

  /// Builds the running arc-length total at each vertex of [puntos].
  static List<double> _longitudesAcumuladas(List<Punto2D> puntos) {
    final acumulado = <double>[0];
    for (var i = 1; i < puntos.length; i++) {
      final dx = puntos[i].x - puntos[i - 1].x;
      final dy = puntos[i].y - puntos[i - 1].y;
      acumulado.add(acumulado[i - 1] + math.sqrt(dx * dx + dy * dy));
    }
    return acumulado;
  }
}
