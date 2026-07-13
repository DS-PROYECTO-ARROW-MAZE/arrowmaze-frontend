import 'package:arrowmaze/di/inyeccion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 36 — levels 16/17/18 are real catalog levels now, loaded through
/// the exact same composition-root path as any other level. The move budget
/// (arrow count + margin) must count arrows across every depth layer, not
/// just layer 0 — otherwise a 3D level's real move budget would silently
/// undercount, shortchanging the player.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('should_size_the_move_budget_from_every_layers_arrows_for_level_16',
      () async {
    final vm = await Inyeccion.construirJuegoViewModelDesdeArchivo(16);
    // level_16.json (the cube) has 7 arrows spread across 3 layers; the
    // budget is arrows + the fixed 5-move margin (Ticket 30).
    expect(vm.estado.movimientosRestantes, 7 + 5);
  });
}
