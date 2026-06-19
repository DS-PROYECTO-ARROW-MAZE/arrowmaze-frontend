/// In-memory board source that lets the tracer-bullet slice run end-to-end.
///
/// It hands back raw cell maps in the same JSON shape as `assets/levels/*.json`
/// so the domain `FabricaCeldasEstandar` builds the board the same way it will
/// for real, file-backed levels (ticket 05 swaps this adapter for a loader
/// without any change to the domain or use cases).
///
/// The board is a 5×5 grid whose every arrow has a clear ray to its edge, so a
/// player can tap them in any order (PRD A3) and each one exits.
class FuenteTableroMemoria {
  /// Stateless adapter.
  const FuenteTableroMemoria();

  /// Rows of the demo board.
  int get filas => 5;

  /// Columns of the demo board.
  int get columnas => 5;

  /// The non-empty cells of the demo board; the rest is transparent space.
  List<Map<String, dynamic>> cargarCeldas() {
    return <Map<String, dynamic>>[
      // Border arrows already touching their edge — exit in one tap (AC4).
      {'row': 0, 'col': 2, 'type': 'arrow', 'direction': 'UP'},
      {'row': 2, 'col': 0, 'type': 'arrow', 'direction': 'LEFT'},
      {'row': 2, 'col': 4, 'type': 'arrow', 'direction': 'RIGHT'},
      {'row': 4, 'col': 2, 'type': 'arrow', 'direction': 'DOWN'},
      // Interior arrows whose rays fly over empties to the edge (AC3).
      {'row': 1, 'col': 1, 'type': 'arrow', 'direction': 'UP'},
      {'row': 3, 'col': 3, 'type': 'arrow', 'direction': 'DOWN'},
      // Decorative walls, off every ray path.
      {'row': 0, 'col': 0, 'type': 'wall'},
      {'row': 4, 'col': 4, 'type': 'wall'},
    ];
  }
}
