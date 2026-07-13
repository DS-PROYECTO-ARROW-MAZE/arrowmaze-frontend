import 'package:arrowmaze/infrastructure/niveles/catalogo_niveles_archivo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 36 — the three 3D boards are real catalog levels (16/17/18), not a
/// QA-only side channel. [CatalogoNivelesArchivo] flags them via [es3D]
/// (derived from the level file's `layers > 1`) so the Level Selection screen
/// can show "3D" instead of a difficulty label, without inventing a fake
/// `Dificultad` value for something that isn't a difficulty (CLAUDE.md:
/// difficulty is data, never a subtype-shaped concept).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('should_flag_levels_16_through_18_as_3d_when_listing_the_catalog',
      () async {
    const catalogo = CatalogoNivelesArchivo();
    final niveles = await catalogo.listar();

    final por3D = {for (final n in niveles) n.id: n.es3D};
    expect(por3D[16], isTrue, reason: 'level 16 (cube) is 3D');
    expect(por3D[17], isTrue, reason: 'level 17 (pyramid) is 3D');
    expect(por3D[18], isTrue, reason: 'level 18 (prism) is 3D');
  });

  test('should_not_flag_the_flat_2d_catalog_levels_as_3d', () async {
    const catalogo = CatalogoNivelesArchivo();
    final niveles = await catalogo.listar();

    final por3D = {for (final n in niveles) n.id: n.es3D};
    for (var id = 1; id <= 15; id++) {
      expect(por3D[id], isFalse, reason: 'level $id is a flat 2D level');
    }
  });

  test('should_include_eighteen_levels_now_that_3d_boards_are_catalogued',
      () async {
    const catalogo = CatalogoNivelesArchivo();
    final cantidad = await catalogo.obtenerCantidadTotal();
    expect(cantidad, 18);
  });
}
