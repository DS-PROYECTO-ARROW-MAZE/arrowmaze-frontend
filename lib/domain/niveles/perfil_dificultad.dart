/// Complexity profile mapping a level number to its difficulty parameters
/// (Ticket 23 — aggressive scaling, unbounded).
///
/// Pure domain data — zero Flutter imports. The curve is steep and monotonic:
/// board size, arrow count, and move budget increase strictly with index.
/// Minimum board size is 7×7 at every index (hard floor).
class PerfilDificultad {
  const PerfilDificultad({
    required this.filas,
    required this.columnas,
    required this.totalCeldas,
    required this.totalFlechas,
    required this.trayectorias,
    required this.presupuestoMovimientos,
  });

  final int filas;
  final int columnas;
  final int totalCeldas;
  final int totalFlechas;
  final int trayectorias;

  /// Move budget (FE-30): how many taps the player gets before game over.
  /// Grows with complexity so the player has proportionally more room on
  /// large boards, but the ratio tightens toward late game.
  final int presupuestoMovimientos;

  /// Returns the difficulty profile for the given 1‑based [nivel].
  ///
  /// The curve is aggressive but unbounded — no cap at level 15.
  /// Board size = 7 + (nivel-1)/5, so every 5 levels adds a row/column.
  /// Trayectorias and arrow counts scale with area.
  static PerfilDificultad para(int nivel) {
    if (nivel < 1) nivel = 1;

    final size = 7 + (nivel - 1) ~/ 5;
    final filas = size;
    final columnas = size;
    final totalCeldas = size * size;

    final trayectorias = size * 2 - 2;
    final totalFlechas = totalCeldas;

    final presupuestoMovimientos = totalFlechas + size * 2;

    return PerfilDificultad(
      filas: filas,
      columnas: columnas,
      totalCeldas: totalCeldas,
      totalFlechas: totalFlechas,
      trayectorias: trayectorias,
      presupuestoMovimientos: presupuestoMovimientos,
    );
  }
}
