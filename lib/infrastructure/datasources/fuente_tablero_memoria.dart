/// In-memory board source that lets the move-mechanic slice run end-to-end.
///
/// It hands back raw path/wall maps in the same JSON shape as
/// `assets/levels/*.json` so the domain `FabricaCeldasEstandar` builds the board
/// the same way it will for real, file-backed levels (ticket 05 swaps this
/// adapter for a loader without any change to the domain or use cases).
///
/// The board is a **fully covered** 5×5 grid: every cell belongs to some arrow
/// path, so there are zero empty cells at the start. Each path's head sits on a
/// border pointing off-board, so every arrow has a clear exit ray and the level
/// is solvable by tapping the paths in any order (PRD A3). Two of the paths bend
/// at 90° corners to exercise the continuous-path renderer.
class FuenteTableroMemoria {
  /// Stateless adapter.
  const FuenteTableroMemoria();

  /// Rows of the demo board.
  int get filas => 5;

  /// Columns of the demo board.
  int get columnas => 5;

  /// The fixed (non-path) cells of the demo board. The board is fully covered by
  /// paths, so there are no walls here.
  List<Map<String, dynamic>> cargarParedes() => const <Map<String, dynamic>>[];

  /// The arrow paths covering the whole board, each `cells` list ordered
  /// tail → head and `head` naming the arrowhead's exit direction.
  List<Map<String, dynamic>> cargarTrayectorias() {
    return <Map<String, dynamic>>[
      // Three straight columns whose heads touch the top edge, pointing up.
      {
        'id': 1,
        'head': 'UP',
        'cells': [
          {'row': 4, 'col': 2},
          {'row': 3, 'col': 2},
          {'row': 2, 'col': 2},
          {'row': 1, 'col': 2},
          {'row': 0, 'col': 2},
        ],
      },
      {
        'id': 2,
        'head': 'UP',
        'cells': [
          {'row': 4, 'col': 3},
          {'row': 3, 'col': 3},
          {'row': 2, 'col': 3},
          {'row': 1, 'col': 3},
          {'row': 0, 'col': 3},
        ],
      },
      {
        'id': 3,
        'head': 'UP',
        'cells': [
          {'row': 4, 'col': 4},
          {'row': 3, 'col': 4},
          {'row': 2, 'col': 4},
          {'row': 1, 'col': 4},
          {'row': 0, 'col': 4},
        ],
      },
      // An L-shaped path bending into the top-left corner, exiting left.
      {
        'id': 4,
        'head': 'LEFT',
        'cells': [
          {'row': 1, 'col': 1},
          {'row': 0, 'col': 1},
          {'row': 0, 'col': 0},
        ],
      },
      // A long snaking path filling the lower-left block, exiting left.
      {
        'id': 5,
        'head': 'LEFT',
        'cells': [
          {'row': 4, 'col': 1},
          {'row': 4, 'col': 0},
          {'row': 3, 'col': 0},
          {'row': 3, 'col': 1},
          {'row': 2, 'col': 1},
          {'row': 2, 'col': 0},
          {'row': 1, 'col': 0},
        ],
      },
    ];
  }
}
