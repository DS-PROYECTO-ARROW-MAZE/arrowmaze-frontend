import '../../domain/niveles/definicion_nivel_remota.dart';

/// DTO for the `POST /levels` request body.
///
/// Serializes a [DefinicionNivelRemota] into the documented contract shape,
/// including the row-major `celdas` grid of `{ x, y, tipo }` objects.
class CrearNivelRequestDto {
  /// Creates the request DTO from a domain definition.
  const CrearNivelRequestDto(this.definicion);

  /// The level definition to send.
  final DefinicionNivelRemota definicion;

  /// Serializes to the contract JSON shape.
  Map<String, dynamic> toJson() => {
        'nombre': definicion.nombre,
        'dificultad': definicion.dificultad.apiToken,
        'ancho': definicion.ancho,
        'alto': definicion.alto,
        'baseNivel': definicion.baseNivel,
        'kmov': definicion.kmov,
        'ktiempo': definicion.ktiempo,
        'umbralEstrella1': definicion.umbralEstrella1,
        'umbralEstrella2': definicion.umbralEstrella2,
        'umbralEstrella3': definicion.umbralEstrella3,
        'celdas': definicion.celdas
            .map((fila) => fila
                .map((c) => {'x': c.x, 'y': c.y, 'tipo': c.tipo})
                .toList())
            .toList(),
      };
}
