import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'delta_tablero.dart';

/// One player move captured as a GoF **Command** object.
///
/// Every tap that counts as a move is encapsulated here so the move can be
/// replayed or undone (ticket 09) without the caller re-deriving what happened.
/// A valid move carries a real [delta] (the board change it caused); an invalid
/// (penalized) move carries **no** delta — it still occupies a slot in history
/// (the anti-cheat +1) but changed nothing on the board.
class PlayerMoveCommand {
  /// Creates a command for the tap at [posicion], optionally carrying the board
  /// [delta] it produced.
  const PlayerMoveCommand({required this.posicion, this.delta});

  /// Where the player tapped.
  final Posicion posicion;

  /// The board change this move applied, or `null` for a no-delta invalid move.
  final DeltaTablero? delta;

  /// Whether this command changed the board (a real delta exists).
  bool get tieneDelta => delta != null;

  /// Reverses this command's effect on [tablero] (GoF **Command** undo).
  ///
  /// A real-delta command restores the whole arrow path it removed (the mirror
  /// re-link on the board); a no-delta invalid command changed nothing on the
  /// board, so its undo is a board no-op — the counter rollback lives in the use
  /// case, not here.
  void deshacer(Tablero tablero) {
    final cambio = delta;
    if (cambio != null) {
      tablero.restaurarTrayectoria(cambio.trayectoria);
    }
  }
}

/// The ordered history of [PlayerMoveCommand]s applied to the board.
///
/// A deep module with a deliberately narrow surface: [push] records a command,
/// while [longitud], [ultimo] and [comandos] expose the trail read-only. Both
/// valid and invalid moves are recorded, so ticket 09's undo can walk a complete,
/// gap-free timeline.
class CommandHistory {
  final List<PlayerMoveCommand> _comandos = <PlayerMoveCommand>[];

  /// Appends [comando] to the end of the history.
  void push(PlayerMoveCommand comando) => _comandos.add(comando);

  /// How many commands have been recorded.
  int get longitud => _comandos.length;

  /// Whether no command has been recorded yet — an undo here is a safe no-op.
  bool get estaVacio => _comandos.isEmpty;

  /// Removes and returns the most recently pushed command (the one an undo
  /// reverses). Throws [StateError] when the history is empty, so callers must
  /// guard with [estaVacio] first.
  PlayerMoveCommand pop() => _comandos.removeLast();

  /// The most recently pushed command. Throws [StateError] when empty.
  PlayerMoveCommand get ultimo => _comandos.last;

  /// The recorded commands in order, as an unmodifiable view.
  List<PlayerMoveCommand> get comandos => List.unmodifiable(_comandos);
}
