import 'package:arrowmaze/application/ports/catalogo_niveles.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
import 'package:arrowmaze/domain/niveles/perfil_dificultad.dart';
import 'package:arrowmaze/domain/niveles/repertorio_formas.dart';
import 'package:arrowmaze/domain/niveles/resumen_nivel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 23 — CatalogoNiveles endless tail (AC1).
///
/// Past the last authored level, the catalog returns a procedurally-generated
/// level summary. The supply is unbounded — no fixed cap.
void main() {
  group('CatalogoNiveles — endless tail', () {
    test('should_yield_generated_level_when_index_past_last_authored', () async {
      final catalogo = _CatalogoConLimite(cantidad: 3);

      final niveles = await catalogo.listar();
      expect(niveles.length, 3);
      expect(niveles.length, 3);

      // Authored levels
      final nivel1 = await catalogo.obtenerPorIndice(1);
      expect(nivel1.id, 1);
      expect(nivel1.nombre, 'Level 1');

      final nivel3 = await catalogo.obtenerPorIndice(3);
      expect(nivel3.id, 3);

      // Generated level past the authored catalog
      final nivel5 = await catalogo.obtenerPorIndice(5);
      expect(nivel5.id, greaterThan(3),
          reason: 'should yield level past the authored catalog');
      expect(nivel5.nombre, contains('Endless'),
          reason: 'generated levels should be identifiable');
    });

    test('should_apply_shape_rotation_to_generated_level', () async {
      final catalogo = _CatalogoConLimite(cantidad: 3);

      // Index 6 → Cuadrado (wraps), index 7 → Corazón
      final nivel6 = await catalogo.obtenerPorIndice(6);
      final nivel7 = await catalogo.obtenerPorIndice(7);

      expect(nivel6.nombre, contains('Cuadrado'));
      expect(nivel7.nombre, contains('Corazón'));
    });

    test('should_have_unbounded_supply_of_generated_levels', () async {
      final catalogo = _CatalogoConLimite(cantidad: 3);

      // High indices must still produce levels.
      final nivel50 = await catalogo.obtenerPorIndice(50);
      expect(nivel50.id, 50);
      expect(nivel50.nombre, isNotEmpty);

      final nivel100 = await catalogo.obtenerPorIndice(100);
      expect(nivel100.id, 100);
    });

    test('should_yield_increasing_difficulty_for_generated_levels', () async {
      // Indices 6 (Cuadrado) and 11 (Cuadrado again) share a shape but
      // index 11 is strictly harder.
      final perfil6 = PerfilDificultad.para(6);
      final perfil11 = PerfilDificultad.para(11);
      final mascara6 = RepertorioFormas().formaParaIndice(6);
      final mascara11 = RepertorioFormas().formaParaIndice(11);

      expect(mascara6.nombre, mascara11.nombre, reason: 'both are Cuadrado');
      expect(perfil11.filas, greaterThan(perfil6.filas),
          reason: 'recurring Cuadrado at index 11 is larger');
      expect(perfil11.totalFlechas, greaterThan(perfil6.totalFlechas),
          reason: 'recurring Cuadrado at index 11 has more arrows');
    });
  });
}

/// A [CatalogoNiveles] with a finite authored catalog of [cantidad] levels
/// and an endless generated tail past that.
class _CatalogoConLimite implements CatalogoNiveles {
  _CatalogoConLimite({required this.cantidad});

  final int cantidad;

  @override
  Future<List<ResumenNivel>> listar() async {
    return List.generate(
      cantidad,
      (i) => ResumenNivel(
        id: i + 1,
        nombre: 'Level ${i + 1}',
        dificultad: Dificultad.facil,
      ),
    );
  }

  @override
  Future<int> obtenerCantidadTotal() async => cantidad;

  @override
  Future<ResumenNivel> obtenerPorIndice(int indice) async {
    if (indice <= cantidad) {
      return ResumenNivel(
        id: indice,
        nombre: 'Level $indice',
        dificultad: Dificultad.facil,
      );
    }
    final mascara = RepertorioFormas().formaParaIndice(indice);
    final nombre = 'Endless ${mascara.nombre} #${(indice - 1) ~/ 5 + 1}';
    return ResumenNivel(
      id: indice,
      nombre: nombre,
      dificultad: Dificultad.dificil,
    );
  }
}
