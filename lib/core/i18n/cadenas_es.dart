import 'cadenas.dart';

/// Recursos de cadenas en español para ArrowMaze.
///
/// Each key from [Cadenas] is implemented here. The class is `const` so a
/// single `const CadenasEs()` instance can be shared across the tree.
class CadenasEs extends Cadenas {
  /// Crea el conjunto de cadenas en español.
  const CadenasEs();

  // ── Auth ───────────────────────────────────────────────────────────────────
  @override
  String get iniciarSesion => 'Iniciar sesión';

  @override
  String get crearCuenta => 'Crear cuenta';

  @override
  String get crearCuentaSubtitulo =>
      'Crea tu cuenta para guardar tu progreso';

  @override
  String get iniciarSesionSubtitulo => 'Inicia sesión para continuar';

  @override
  String get campoUsuario => 'Usuario';

  @override
  String get campoEmail => 'Correo electrónico';

  @override
  String get campoContrasena => 'Contraseña';

  @override
  String get registrar => 'Registrarse';

  @override
  String get requerido => 'Requerido';

  @override
  String get emailInvalido => 'Ingresa un correo válido';

  @override
  String get contrasenaMinima => 'Mínimo 6 caracteres';

  @override
  String get yaTieneCuenta => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get noTieneCuenta => '¿No tienes cuenta? Crea una';

  @override
  String get continuarInvitado => 'Continuar como invitado';

  // ── Nivel Select ──────────────────────────────────────────────────────────
  @override
  String get seleccionarNivel => 'Seleccionar nivel';

  @override
  String get cerrarSesion => 'Cerrar sesión';

  @override
  String get sinNiveles => 'No hay niveles disponibles.';

  @override
  String get facil => 'Fácil';

  @override
  String get medio => 'Medio';

  @override
  String get dificil => 'Difícil';

  // ── Juego ─────────────────────────────────────────────────────────────────
  @override
  String get pantallaJuego => 'ArrowMaze';

  @override
  String get tableroDeClasificacion => 'Clasificación';

  @override
  String get alternarSonido => 'Alternar sonido';

  @override
  String get deshacer => 'Deshacer';

  @override
  String deshacerConUsos(int n) => 'Deshacer ($n restantes)';

  @override
  String get pista => 'Pista';

  @override
  String get pistaUsada => 'Pista ya usada';

  @override
  String pistaBloqueada(int segundos) =>
      'Pista bloqueada — disponible en ${segundos}s';

  @override
  String get pausar => 'Pausar';

  @override
  String get reanudar => 'Reanudar';

  @override
  String get pausado => 'Pausado';

  @override
  String get victoria => '¡Victoria!';

  @override
  String limpiadoEn(int movimientos) =>
      'Completado en $movimientos movimientos';

  @override
  String get tiempoAgotado => '¡Se acabó el tiempo!';

  @override
  String get movimientosAgotados => 'Sin movimientos';

  @override
  String get sinTiempo => 'Se te acabó el tiempo';

  @override
  String get sinMovimientos => 'Se te acabaron los movimientos';

  @override
  String get siguienteNivel => 'Siguiente nivel';

  @override
  String get reintentar => 'Reintentar';

  @override
  String get seleccionNiveles => 'Selección de niveles';

  @override
  String noPudoCargarNivel(int id) => 'No se pudo cargar el nivel $id.';

  // ── Clasificación ─────────────────────────────────────────────────────────
  @override
  String get sinPuntuaciones => 'Aún no hay puntuaciones para este nivel.';

  @override
  String get seleccionaNivelParaPuntuaciones =>
      'Selecciona un nivel para ver las puntuaciones';

  @override
  String get noPudoCargarse => 'No se pudo cargar la clasificación.';

  // ── HUD ───────────────────────────────────────────────────────────────────
  @override
  String get etiquetaMovimientos => 'Mov.: ';

  // ── Ajustes ───────────────────────────────────────────────────────────────
  @override
  String get ajustes => 'Ajustes';

  @override
  String get sonido => 'Sonido';

  @override
  String get idioma => 'Idioma';

  @override
  String get ingles => 'Inglés';

  @override
  String get espanol => 'Español';
}
