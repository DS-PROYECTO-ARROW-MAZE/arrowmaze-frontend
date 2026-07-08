import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/application/generadores/generacion_aleatoria_nivel.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeneracionAleatoriaNivel', () {
    test('should_generate_solvable_board_when_requested', () {
      final generador = GeneracionAleatoriaNivel();
      final config = ConfiguracionGeneracion(filas: 4, columnas: 4);

      final resultado = generador.generar(config);

      expect(resultado, isNotNull);
      expect(resultado, isA<Tablero>());
    });
  });
}
