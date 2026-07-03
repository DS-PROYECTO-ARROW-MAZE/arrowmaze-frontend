import 'mascara_forma.dart';

/// A fixed, ordered repertoire of predefined shape masks (Ticket 23 — AC3).
///
/// Shapes cycle deterministically: index 1→Cuadrado, 2→Corazón, 3→Triángulo,
/// 4→Cruz, 5→Estrella, 6→Cuadrado (wraps). The caller never branches on the
/// shape name — shape is data, consumed purely through [MascaraForma.ausentes].
///
/// Shape and difficulty are orthogonal axes. The same shape recurs as the
/// level index grows, but each recurrence is at strictly higher complexity
/// (driven by [PerfilDificultad], never by swapping the shape).
class RepertorioFormas {
  /// The fixed ordered repertoire.
  static const _formas = [
    MascaraForma('Cuadrado', funcionCuadrado),
    MascaraForma('Corazón', funcionCorazon),
    MascaraForma('Triángulo', funcionTriangulo),
    MascaraForma('Cruz', funcionCruz),
    MascaraForma('Estrella', funcionEstrella),
  ];

  static const _longitud = 5;

  /// Returns the shape for the given 1‑based [numero] (level index).
  ///
  /// Rotates deterministically through the repertoire: (numero - 1) % length.
  MascaraForma formaParaIndice(int numero) {
    final idx = (numero - 1) % _longitud;
    return _formas[idx];
  }
}
