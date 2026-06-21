import 'package:arrowmaze/application/ports/fuente_niveles.dart';
import 'package:arrowmaze/application/use_cases/crear_nivel_use_case.dart';
import 'package:arrowmaze/domain/niveles/celda_nivel.dart';
import 'package:arrowmaze/domain/niveles/definicion_nivel_remota.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
import 'package:arrowmaze/domain/niveles/nivel_creado.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 14 — RED: CrearNivelUseCase (`POST /levels`).
void main() {
  group('CrearNivelUseCase', () {
    test('should_return_created_level_when_crear_succeeds', () async {
      // Arrange
      final port = _FuenteNivelesFake();
      final useCase = CrearNivelUseCase(fuenteNiveles: port);
      const definicion = DefinicionNivelRemota(
        nombre: 'Nivel 1 - El Despertar',
        dificultad: Dificultad.facil,
        ancho: 3,
        alto: 1,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 5,
        umbralEstrella1: 300,
        umbralEstrella2: 600,
        umbralEstrella3: 900,
        celdas: [
          [CeldaNivel(x: 0, y: 0, tipo: 'inicio')],
        ],
      );

      // Act
      final creado = await useCase.ejecutar(definicion);

      // Assert
      expect(creado.id, 'uuid-nivel');
      expect(creado.nombre, 'Nivel 1 - El Despertar');
      expect(port.recibida?.nombre, 'Nivel 1 - El Despertar');
    });
  });
}

class _FuenteNivelesFake implements FuenteNiveles {
  DefinicionNivelRemota? recibida;

  @override
  Future<NivelCreado> crear(DefinicionNivelRemota definicion) async {
    recibida = definicion;
    return NivelCreado(id: 'uuid-nivel', nombre: definicion.nombre);
  }
}
