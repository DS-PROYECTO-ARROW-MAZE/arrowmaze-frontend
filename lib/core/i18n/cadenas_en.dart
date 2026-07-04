import 'cadenas.dart';

/// English string resources for ArrowMaze.
///
/// Every key from [Cadenas] must be implemented here. The class is `const` so
/// a single `const CadenasEn()` instance can be shared across the tree.
class CadenasEn extends Cadenas {
  /// Creates the English string set.
  const CadenasEn();

  // ── Auth ───────────────────────────────────────────────────────────────────
  @override
  String get iniciarSesion => 'Sign In';

  @override
  String get crearCuenta => 'Create Account';

  @override
  String get crearCuentaSubtitulo => 'Create your account to save progress';

  @override
  String get iniciarSesionSubtitulo => 'Sign in to continue';

  @override
  String get campoUsuario => 'Username';

  @override
  String get campoEmail => 'Email';

  @override
  String get campoContrasena => 'Password';

  @override
  String get registrar => 'Register';

  @override
  String get requerido => 'Required';

  @override
  String get emailInvalido => 'Enter a valid email';

  @override
  String get contrasenaMinima => 'At least 6 characters';

  @override
  String get yaTieneCuenta => 'Already have an account? Sign In';

  @override
  String get noTieneCuenta => "Don't have an account? Create one";

  @override
  String get continuarInvitado => 'Continue as guest';

  // ── Level Select ──────────────────────────────────────────────────────────
  @override
  String get seleccionarNivel => 'Select Level';

  @override
  String get cerrarSesion => 'Logout';

  @override
  String get sinNiveles => 'No levels available.';

  @override
  String get facil => 'Easy';

  @override
  String get medio => 'Medium';

  @override
  String get dificil => 'Hard';

  // ── Game ──────────────────────────────────────────────────────────────────
  @override
  String get pantallaJuego => 'ArrowMaze';

  @override
  String get tableroDeClasificacion => 'Leaderboard';

  @override
  String get alternarSonido => 'Toggle sound';

  @override
  String get deshacer => 'Undo';

  @override
  String deshacerConUsos(int n) => 'Undo ($n left)';

  @override
  String get pausar => 'Pause';

  @override
  String get reanudar => 'Resume';

  @override
  String get pausado => 'Paused';

  @override
  String get victoria => 'Victory!';

  @override
  String limpiadoEn(int movimientos) => 'Cleared in $movimientos moves';

  @override
  String get tiempoAgotado => "Time's up";

  @override
  String get movimientosAgotados => 'No moves left';

  @override
  String get sinTiempo => 'You ran out of time';

  @override
  String get sinMovimientos => 'You ran out of moves';

  @override
  String get siguienteNivel => 'Next Level';

  @override
  String get reintentar => 'Retry';

  @override
  String get seleccionNiveles => 'Level Select';

  @override
  String noPudoCargarNivel(int id) => 'Could not load level $id.';

  // ── Leaderboard ───────────────────────────────────────────────────────────
  @override
  String get sinPuntuaciones => 'No scores yet for this level.';

  @override
  String get seleccionaNivelParaPuntuaciones =>
      'Select a level to view scores';

  @override
  String get noPudoCargarse => 'Could not load leaderboard.';

  // ── HUD ───────────────────────────────────────────────────────────────────
  @override
  String get etiquetaMovimientos => 'Moves: ';

  // ── Settings ──────────────────────────────────────────────────────────────
  @override
  String get ajustes => 'Settings';

  @override
  String get sonido => 'Sound';

  @override
  String get idioma => 'Language';

  @override
  String get ingles => 'English';

  @override
  String get espanol => 'Spanish';
}
