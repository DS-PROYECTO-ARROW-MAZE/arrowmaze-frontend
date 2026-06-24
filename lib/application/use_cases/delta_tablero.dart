import '../../domain/entities/trayectoria.dart';

/// The board change one move applied — the *data* a caller branches on instead
/// of the move's type (Clean Architecture: behaviour decided by data, not by
/// `is`-checks).
///
/// A valid move carries a real delta (the whole arrow [Trayectoria] that left
/// the board); an invalid (penalized) move carries **no** delta at all, modelled
/// as a `null` `DeltaTablero` on the `ResultadoMovimiento`. Keeping the removed
/// path here is what lets the GoF **Command** undo the move later (ticket 09).
class DeltaTablero {
  /// A delta describing the removal of the whole [trayectoria] from the board.
  const DeltaTablero.eliminacion(this.trayectoria);

  /// The arrow path that left the board on this move (enough to restore it on
  /// undo).
  final Trayectoria trayectoria;
}
