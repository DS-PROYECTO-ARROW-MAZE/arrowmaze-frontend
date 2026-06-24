import 'celda_nivel.dart';
import 'dificultad.dart';

/// The full definition of a level to create on the backend (`POST /levels`).
///
/// Pure domain value object — no Flutter, no infrastructure. The infrastructure
/// layer maps this to the request DTO.
class DefinicionNivelRemota {
  /// Creates a remote level definition.
  const DefinicionNivelRemota({
    required this.nombre,
    required this.dificultad,
    required this.ancho,
    required this.alto,
    required this.baseNivel,
    required this.kmov,
    required this.ktiempo,
    required this.umbralEstrella1,
    required this.umbralEstrella2,
    required this.umbralEstrella3,
    required this.celdas,
  });

  /// Human-readable level name.
  final String nombre;

  /// Difficulty bucket.
  final Dificultad dificultad;

  /// Board width in cells.
  final int ancho;

  /// Board height in cells.
  final int alto;

  /// Base score before penalties.
  final int baseNivel;

  /// Per-move penalty coefficient.
  final int kmov;

  /// Per-second time coefficient.
  final int ktiempo;

  /// Score threshold for one star.
  final int umbralEstrella1;

  /// Score threshold for two stars.
  final int umbralEstrella2;

  /// Score threshold for three stars.
  final int umbralEstrella3;

  /// The board grid, row-major: `celdas[y][x]`.
  final List<List<CeldaNivel>> celdas;
}
