class DefinicionNivelDto {
  const DefinicionNivelDto({
    required this.id,
    required this.filas,
    required this.columnas,
    this.layers = 1,
    required this.trayectorias,
    required this.celdas,
    this.ausentes = const <Map<String, dynamic>>[],
  });

  final int id;
  final int filas;
  final int columnas;

  /// Number of depth layers the level defines; `1` for a 2D level.
  final int layers;
  final List<Map<String, dynamic>> trayectorias;
  final List<Map<String, dynamic>> celdas;

  /// Cells explicitly marked as absent (outside the playable region).
  final List<Map<String, dynamic>> ausentes;
}
