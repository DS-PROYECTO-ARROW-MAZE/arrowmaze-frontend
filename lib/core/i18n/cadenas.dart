/// Abstract interface for all user-facing strings in the app.
///
/// Every key is a getter or method — getters for static strings, methods for
/// parametric ones. Views read strings exclusively through this interface via
/// [CadenasScope.of(context)] so no hard-coded literals remain in the UI (AC3).
///
/// Concrete implementations live in [CadenasEn] and [CadenasEs]. Adding a new
/// language requires a single new subclass — no existing code changes (OCP).
abstract class Cadenas {
  /// Allows `const` subclasses.
  const Cadenas();

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// AppBar title on the login form.
  String get iniciarSesion;

  /// AppBar title on the register form.
  String get crearCuenta;

  /// Subtitle shown below the brand logo when registering.
  String get crearCuentaSubtitulo;

  /// Subtitle shown below the brand logo when logging in.
  String get iniciarSesionSubtitulo;

  /// Label for the username field.
  String get campoUsuario;

  /// Label for the email field.
  String get campoEmail;

  /// Label for the password field.
  String get campoContrasena;

  /// Register button label.
  String get registrar;

  /// Validator message: field is empty.
  String get requerido;

  /// Validator message: email format is invalid.
  String get emailInvalido;

  /// Validator message: password is too short.
  String get contrasenaMinima;

  /// Toggle-mode link shown when registering.
  String get yaTieneCuenta;

  /// Toggle-mode link shown when logging in.
  String get noTieneCuenta;

  /// Skip-auth / guest button.
  String get continuarInvitado;

  // ── Level Select ──────────────────────────────────────────────────────────

  /// AppBar title for the level-selection screen.
  String get seleccionarNivel;

  /// Logout icon-button tooltip.
  String get cerrarSesion;

  /// Empty-state body when no levels are available.
  String get sinNiveles;

  /// Difficulty chip label — easy.
  String get facil;

  /// Difficulty chip label — medium.
  String get medio;

  /// Difficulty chip label — hard.
  String get dificil;

  // ── Game ──────────────────────────────────────────────────────────────────

  /// AppBar title for the game screen (brand name, same in all locales).
  String get pantallaJuego;

  /// Leaderboard icon-button tooltip.
  String get tableroDeClasificacion;

  /// Sound-mute icon-button tooltip.
  String get alternarSonido;

  /// Undo icon-button tooltip (no remaining uses context).
  String get deshacer;

  /// Undo icon-button tooltip with remaining-uses count.
  String deshacerConUsos(int n);

  /// Pause icon-button tooltip.
  String get pausar;

  /// Resume icon-button tooltip (also used on the pause overlay button).
  String get reanudar;

  /// Pause overlay title.
  String get pausado;

  /// Victory overlay heading.
  String get victoria;

  /// Victory overlay sub-line with move count.
  String limpiadoEn(int movimientos);

  /// Defeat heading — timer ran out.
  String get tiempoAgotado;

  /// Defeat heading — move budget exhausted.
  String get movimientosAgotados;

  /// Defeat body — timer variant.
  String get sinTiempo;

  /// Defeat body — moves variant.
  String get sinMovimientos;

  /// End-of-game "Next Level" button.
  String get siguienteNivel;

  /// End-of-game "Retry" button.
  String get reintentar;

  /// End-of-game "Level Select" button.
  String get seleccionNiveles;

  /// Error body shown when a level file cannot be loaded.
  String noPudoCargarNivel(int id);

  // ── Leaderboard ───────────────────────────────────────────────────────────

  /// Empty state when no scores have been posted yet.
  String get sinPuntuaciones;

  /// Initial state before any level is selected.
  String get seleccionaNivelParaPuntuaciones;

  /// Error state when the leaderboard fetch fails.
  String get noPudoCargarse;

  // ── HUD ───────────────────────────────────────────────────────────────────

  /// Prefix label for the move counter in the HUD (e.g. "Moves: ").
  String get etiquetaMovimientos;

  // ── Settings ──────────────────────────────────────────────────────────────

  /// AppBar title for the settings screen and the settings button tooltip.
  String get ajustes;

  /// Label for the sound toggle setting.
  String get sonido;

  /// Label for the language setting section.
  String get idioma;

  /// Language option label — English.
  String get ingles;

  /// Language option label — Spanish.
  String get espanol;
}
