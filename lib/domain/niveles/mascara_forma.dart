import 'dart:math' as math;

import '../value_objects/posicion.dart';

/// A predefined shape mask that defines the playable region of a board
/// (Ticket 23 — shape rotation, orthogonal to difficulty).
///
/// The mask uses the *absent-position* concept from FE-16: positions outside
/// the shape are excluded from the playable region. The generator populates
/// only playable (in-mask) positions; absent positions stay absent.
///
/// Shape and difficulty are orthogonal axes. The shape is chosen by
/// [RepertorioFormas.formaParaIndice], independent of [PerfilDificultad].
class MascaraForma {
  /// Creates a shape mask.
  ///
  /// [nombre] is the human-readable shape name (e.g. "Cuadrado", "Corazón").
  /// [_esPlayable] is a predicate `(fila, columna, filas, columnas) → bool`
  /// that returns `true` for positions inside the shape.
  const MascaraForma(this.nombre, this._esPlayable);

  /// Human-readable identifier for this shape.
  final String nombre;

  final bool Function(int fila, int columna, int filas, int columnas)
      _esPlayable;

  /// Returns the set of positions **excluded** from the playable region
  /// for a grid of [filas] × [columnas].
  Set<Posicion> ausentes(int filas, int columnas) {
    final result = <Posicion>{};
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (!_esPlayable(f, c, filas, columnas)) {
          result.add(Posicion.en(fila: f, columna: c));
        }
      }
    }
    return result;
  }
}

/// Built-in shape predicates.

/// Full rectangle — every grid cell is playable.
bool funcionCuadrado(int f, int c, int filas, int columnas) => true;

/// Heart shape using the classic heart curve inequality
/// (x² + y² - 1)³ - x²·y³ ≤ 0, normalised to [-1, 1].
bool funcionCorazon(int f, int c, int filas, int columnas) {
  final cx = (columnas - 1) / 2;
  final cy = (filas - 1) / 2;
  if (cx == 0 || cy == 0) return true;
  final dx = (c - cx) / cx;
  final dy = (f - cy) / cy;
  final x2 = dx * dx;
  final y2 = dy * dy;
  final val =
      (x2 + y2 - 1) * (x2 + y2 - 1) * (x2 + y2 - 1) - x2 * dy * dy * dy;
  return val <= 0;
}

/// Isosceles triangle pointing up (base at bottom, apex at top-center).
bool funcionTriangulo(int f, int c, int filas, int columnas) {
  if (filas <= 1) return true;
  final cx = (columnas - 1) / 2;
  final relF = f / (filas - 1); // 0 at top, 1 at bottom
  final halfWidthAtF = relF * cx;
  return c >= cx - halfWidthAtF && c <= cx + halfWidthAtF;
}

/// Cross: a vertical bar over a horizontal bar.
bool funcionCruz(int f, int c, int filas, int columnas) {
  final cx = (columnas - 1) / 2;
  final cy = (filas - 1) / 2;
  final thick = math.max(columnas, filas) ~/ 4;
  final inVertical = c >= cx - thick && c <= cx + thick;
  final inHorizontal = f >= cy - thick && f <= cy + thick;
  return inVertical || inHorizontal;
}

/// 4-pointed star: a diamond (|x| + |y| ≤ 1) overlaid with a thin cross
/// for the points.
bool funcionEstrella(int f, int c, int filas, int columnas) {
  final cx = (columnas - 1) / 2;
  final cy = (filas - 1) / 2;
  if (cx == 0 || cy == 0) return true;
  final dx = (c - cx) / cx;
  final dy = (f - cy) / cy;
  final x = dx.abs();
  final y = dy.abs();
  // Diamond body + thin arms
  return x + y <= 1.0 || (x <= 0.25 && y <= 1.0) || (y <= 0.25 && x <= 1.0);
}
