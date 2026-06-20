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

  /// The most recently pushed command. Throws [StateError] when empty.
  PlayerMoveCommand get ultimo => _comandos.last;

  /// The recorded commands in order, as an unmodifiable view.
  List<PlayerMoveCommand> get comandos => List.unmodifiable(_comandos);
}
