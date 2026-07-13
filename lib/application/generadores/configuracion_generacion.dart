import 'package:arrowmaze/domain/value_objects/posicion.dart';

/// Tuning parameters for the level generation template method.
///
/// [ausentes] defines the board's shape: positions outside the playable region
/// (like the void in a heart- or triangle-shaped board). An empty set means a
/// full rectangle — the default.
class ConfiguracionGeneracion {
  const ConfiguracionGeneracion({
    required this.filas,
    required this.columnas,
    this.profundo = 1,
    this.ausentes = const <Posicion>{},
  });

  final int filas;
  final int columnas;

  /// Number of depth layers; `1` for a 2D board.
  final int profundo;

  /// Positions excluded from the playable region of a shaped board.
  final Set<Posicion> ausentes;
}
