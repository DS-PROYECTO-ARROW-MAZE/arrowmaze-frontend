/// Complexity profile mapping a level number to its target metrics
/// (Ticket 17, DM-F3 — cross-repo agreement with backend `PerfilDificultad`).
///
/// Pure domain data — zero Flutter imports. Profiles are monotonic
/// non-decreasing in cells, arrows, and trayectorias across levels 1…15.
class PerfilDificultad {
  const PerfilDificultad({
    required this.filas,
    required this.columnas,
    required this.totalCeldas,
    required this.totalFlechas,
    required this.trayectorias,
  });

  /// Grid rows.
  final int filas;

  /// Grid columns.
  final int columnas;

  /// Total cells in the grid (= filas × columnas when rectangular).
  final int totalCeldas;

  /// Total arrow segments (arrows array length).
  final int totalFlechas;

  /// Number of distinct arrow paths (trayectorias).
  final int trayectorias;

  /// Returns the complexity profile for the given [nivel] (1‑based).
  ///
  /// Progression is strictly monotonic: levels 1‑5 are 5×5 (25 cells,
  /// 5‑6 arrows), levels 6‑10 are 6×6 (36 cells, 8‑11 arrows), and
  /// levels 11‑15 are 7×7 (49 cells, 12‑15 arrows).
  static PerfilDificultad para(int nivel) {
    if (nivel <= 0) nivel = 1;
    if (nivel > 15) nivel = 15;

    if (nivel <= 5) {
      // 5×5 grid, 25 cells, 5‑6 trayectorias
      const baseFilas = 5;
      const baseColumnas = 5;
      const baseCeldas = 25;
      final trayectorias = nivel <= 3 ? 5 : 6;
      final flechas = trayectorias * baseColumnas;
      return PerfilDificultad(
        filas: baseFilas,
        columnas: baseColumnas,
        totalCeldas: baseCeldas,
        totalFlechas: flechas,
        trayectorias: trayectorias,
      );
    } else if (nivel <= 10) {
      // 6×6 grid, 36 cells, 7‑11 trayectorias
      const baseFilas = 6;
      const baseColumnas = 6;
      const baseCeldas = 36;
      final trayectorias = nivel - 5 + 6; // 7→11
      final flechas = trayectorias * (baseColumnas - 1);
      return PerfilDificultad(
        filas: baseFilas,
        columnas: baseColumnas,
        totalCeldas: baseCeldas,
        totalFlechas: flechas,
        trayectorias: trayectorias,
      );
    } else {
      // 7×7 grid, 49 cells, 12‑15 trayectorias
      const baseFilas = 7;
      const baseColumnas = 7;
      const baseCeldas = 49;
      final trayectorias = nivel - 11 + 11; // 11→15
      final flechas = trayectorias * (baseColumnas - 1);
      return PerfilDificultad(
        filas: baseFilas,
        columnas: baseColumnas,
        totalCeldas: baseCeldas,
        totalFlechas: flechas,
        trayectorias: trayectorias,
      );
    }
  }
}
