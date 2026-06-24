import 'entities/celda.dart';
import 'tablero.dart';
import 'value_objects/posicion.dart';

/// Greedy solvability checker for [Tablero].
///
/// A board is solvable if some sequence of valid moves empties it. The greedy
/// algorithm — repeatedly remove any arrow whose head ray is clear to the board
/// edge — is a **complete, polynomial** decision procedure: no backtracking is
/// needed, because removals only clear cells and can never make a solvable board
/// unsolvable. The board empties iff it is solvable (CONTEXT.md §Solvencia).
///
/// This is a pure domain service: it depends only on the [Tablero] port and never
/// imports Flutter. The caller is responsible for providing a **copy** of the
/// board, since [eliminarTrayectoria] mutates it.
class Solver {
  /// Determines whether [tablero] is solvable.
  ///
  /// The algorithm works on the given [tablero] directly, mutating it as it
  /// greedily removes clearable paths. Callers that need the original board
  /// intact must pass a copy.
  static bool esSolvable(Tablero tablero) {
    var progreso = true;
    while (progreso) {
      progreso = false;
      for (var fila = 0; fila < tablero.filas; fila++) {
        for (var columna = 0; columna < tablero.columnas; columna++) {
          final posicion = Posicion.en(fila: fila, columna: columna);
          final celda = tablero.celdaEn(posicion);
          if (celda is! CeldaFlecha) continue;
          final trayectoria = tablero.trayectoriaEn(posicion);
          if (trayectoria == null) continue;
          final rayo =
              tablero.raycast(trayectoria.cabeza, trayectoria.direccionCabeza);
          if (rayo.despejadoHastaBorde) {
            tablero.eliminarTrayectoria(trayectoria.id);
            progreso = true;
          }
        }
      }
    }

    for (var fila = 0; fila < tablero.filas; fila++) {
      for (var columna = 0; columna < tablero.columnas; columna++) {
        if (tablero.celdaEn(Posicion.en(fila: fila, columna: columna))
            is CeldaFlecha) {
          return false;
        }
      }
    }
    return true;
  }
}
