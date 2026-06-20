class DefinicionNivelDto {
  const DefinicionNivelDto({
    required this.id,
    required this.filas,
    required this.columnas,
    required this.trayectorias,
    required this.celdas,
  });

  final int id;
  final int filas;
  final int columnas;
  final List<Map<String, dynamic>> trayectorias;
  final List<Map<String, dynamic>> celdas;
}
