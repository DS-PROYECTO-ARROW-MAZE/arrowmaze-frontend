import '../value_objects/direccion.dart';
import '../value_objects/posicion.dart';
import 'celda.dart';

/// Factory Method that turns a level's JSON cell map into the right [Celda].
///
/// Callers depend only on the [Celda] abstraction: they ask for a cell and get
/// the correct kind back, with no `if (type == 'arrow') …` ladder of their own
/// (OCP). Adding a new cell kind means extending this one switch, not editing
/// every call site.
///
/// Expected map shape (see `assets/levels/*.json`):
/// `{"row": int, "col": int, "type": "arrow|wall|empty", "direction": "UP|DOWN|LEFT|RIGHT"}`.
class FabricaCeldasEstandar {
  /// Creates the factory. Stateless — safe to share as a `const`.
  const FabricaCeldasEstandar();

  /// Builds the [Celda] described by [json].
  ///
  /// Throws [ArgumentError] for an unknown `type` or a missing/invalid
  /// `direction` on an arrow — malformed level data should fail loudly.
  Celda crear(Map<String, dynamic> json) {
    final posicion = Posicion.en(
      fila: json['row'] as int,
      columna: json['col'] as int,
    );
    final tipo = json['type'] as String;

    switch (tipo) {
      case 'arrow':
        return CeldaFlecha(
          posicion: posicion,
          direccion: _direccionDesde(json['direction'] as String?),
        );
      case 'wall':
        return CeldaPared(posicion);
      case 'empty':
        return CeldaVacia(posicion);
      default:
        throw ArgumentError.value(tipo, 'type', 'Unknown cell type');
    }
  }

  /// Maps a JSON direction token to its [Direccion].
  Direccion _direccionDesde(String? token) {
    switch (token) {
      case 'UP':
        return Direccion.arriba;
      case 'DOWN':
        return Direccion.abajo;
      case 'LEFT':
        return Direccion.izquierda;
      case 'RIGHT':
        return Direccion.derecha;
      default:
        throw ArgumentError.value(token, 'direction', 'Unknown direction');
    }
  }
}
