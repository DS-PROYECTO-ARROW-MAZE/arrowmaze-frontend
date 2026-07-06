/// Port for reading and writing user preferences (sound toggle + language).
///
/// Implementations live in `infrastructure/`; the port is consumed by
/// [ConfiguracionManager] in `core/`, keeping both `domain/` and `application/`
/// Flutter-free (ADR-0002). The split between the two concerns (sound and
/// language) is intentional — each setting is independently readable/writable.
abstract interface class PreferenciasUsuario {
  /// Returns whether sound effects are enabled.
  ///
  /// Defaults to `true` on first run (no stored value).
  Future<bool> leerSonidoHabilitado();

  /// Returns the saved language code (`'en'` or `'es'`).
  ///
  /// Returns `null` on first run so the caller can apply the device-locale
  /// default (AC5) without the port needing to know about the device.
  Future<String?> leerIdioma();

  /// Persists [habilitado] as the new sound-enabled flag.
  Future<void> guardarSonidoHabilitado(bool habilitado);

  /// Persists [idioma] as the active language code.
  Future<void> guardarIdioma(String idioma);
}
