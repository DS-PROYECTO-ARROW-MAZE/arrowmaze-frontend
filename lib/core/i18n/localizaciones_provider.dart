import 'cadenas.dart';
import 'cadenas_en.dart';
import 'cadenas_es.dart';

/// Maps a language code to the corresponding [Cadenas] implementation.
///
/// Acts as a pure factory: given an [idioma] code (`'en'` or `'es'`), it
/// returns the matching concrete [Cadenas]. Unknown codes fall back to English
/// so the UI never renders with missing strings (AC3 — no literal fallbacks).
///
/// Used in the composition root (`main.dart`) to feed the [CadenasScope] that
/// propagates the active strings through the widget tree.
abstract final class LocalizacionesProvider {
  /// Returns [CadenasEn] for `'en'`, [CadenasEs] for `'es'`, or [CadenasEn]
  /// for any unrecognised code.
  static Cadenas cadenasPara(String idioma) {
    return switch (idioma) {
      'es' => const CadenasEs(),
      _ => const CadenasEn(),
    };
  }
}
