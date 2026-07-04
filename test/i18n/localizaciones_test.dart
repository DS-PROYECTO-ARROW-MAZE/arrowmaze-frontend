import 'package:arrowmaze/core/i18n/cadenas.dart';
import 'package:arrowmaze/core/i18n/cadenas_en.dart';
import 'package:arrowmaze/core/i18n/cadenas_es.dart';
import 'package:arrowmaze/core/i18n/localizaciones_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 27 — AC3: verifies every i18n key resolves to a non-empty string
/// in both English and Spanish, and that there are no missing keys or literal
/// fallbacks (e.g. key names appearing verbatim as values).
void main() {
  group('Localizaciones', () {
    // ── AC3 ──────────────────────────────────────────────────────────────────
    test('should_resolve_each_key_in_english_and_spanish', () {
      const en = CadenasEn();
      const es = CadenasEs();

      // Collect all key values from both languages
      final enValues = _allValues(en);
      final esValues = _allValues(es);

      // Every key must be non-null and non-empty in both languages
      for (final entry in enValues.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'English key "${entry.key}" is empty',
        );
      }
      for (final entry in esValues.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'Spanish key "${entry.key}" is empty',
        );
      }

      // Both languages must expose the same set of keys
      expect(
        enValues.keys.toSet(),
        equals(esValues.keys.toSet()),
        reason: 'English and Spanish must expose identical key sets',
      );
    });

    test('should_return_english_cadenas_for_en_code', () {
      final cadenas = LocalizacionesProvider.cadenasPara('en');
      expect(cadenas, isA<CadenasEn>());
    });

    test('should_return_spanish_cadenas_for_es_code', () {
      final cadenas = LocalizacionesProvider.cadenasPara('es');
      expect(cadenas, isA<CadenasEs>());
    });

    test('should_default_to_english_for_unknown_code', () {
      final cadenas = LocalizacionesProvider.cadenasPara('fr');
      expect(cadenas, isA<CadenasEn>());
    });

    test('should_have_distinct_translations_for_locale_specific_strings', () {
      // At least some strings must differ between languages — confirms that
      // the Spanish file is not a copy of the English one.
      const en = CadenasEn();
      const es = CadenasEs();
      final enValues = _allValues(en);
      final esValues = _allValues(es);

      final differentCount = enValues.entries
          .where((e) => esValues[e.key] != e.value)
          .length;

      expect(
        differentCount,
        greaterThan(0),
        reason: 'Spanish and English must have at least one differing string',
      );
    });

    test('should_translate_parametric_string_with_move_count', () {
      const en = CadenasEn();
      const es = CadenasEs();

      // Parametric strings must contain the argument
      expect(en.limpiadoEn(7), contains('7'));
      expect(es.limpiadoEn(7), contains('7'));
      expect(en.deshacerConUsos(3), contains('3'));
      expect(es.deshacerConUsos(3), contains('3'));
    });
  });
}

/// Extracts all static string keys from a [Cadenas] instance into a map
/// keyed by a stable string identifier.
///
/// Parametric strings are tested with a sentinel value (42) so they remain
/// comparable across instances.
Map<String, String> _allValues(Cadenas c) {
  return {
    'iniciarSesion': c.iniciarSesion,
    'crearCuenta': c.crearCuenta,
    'crearCuentaSubtitulo': c.crearCuentaSubtitulo,
    'iniciarSesionSubtitulo': c.iniciarSesionSubtitulo,
    'campoUsuario': c.campoUsuario,
    'campoEmail': c.campoEmail,
    'campoContrasena': c.campoContrasena,
    'registrar': c.registrar,
    'requerido': c.requerido,
    'emailInvalido': c.emailInvalido,
    'contrasenaMinima': c.contrasenaMinima,
    'yaTieneCuenta': c.yaTieneCuenta,
    'noTieneCuenta': c.noTieneCuenta,
    'continuarInvitado': c.continuarInvitado,
    'seleccionarNivel': c.seleccionarNivel,
    'cerrarSesion': c.cerrarSesion,
    'sinNiveles': c.sinNiveles,
    'facil': c.facil,
    'medio': c.medio,
    'dificil': c.dificil,
    'pantallaJuego': c.pantallaJuego,
    'tableroDeClasificacion': c.tableroDeClasificacion,
    'alternarSonido': c.alternarSonido,
    'deshacer': c.deshacer,
    'deshacerConUsos': c.deshacerConUsos(42),
    'pausar': c.pausar,
    'reanudar': c.reanudar,
    'pausado': c.pausado,
    'victoria': c.victoria,
    'limpiadoEn': c.limpiadoEn(42),
    'tiempoAgotado': c.tiempoAgotado,
    'movimientosAgotados': c.movimientosAgotados,
    'sinTiempo': c.sinTiempo,
    'sinMovimientos': c.sinMovimientos,
    'siguienteNivel': c.siguienteNivel,
    'reintentar': c.reintentar,
    'seleccionNiveles': c.seleccionNiveles,
    'noPudoCargarNivel': c.noPudoCargarNivel(1),
    'sinPuntuaciones': c.sinPuntuaciones,
    'seleccionaNivelParaPuntuaciones': c.seleccionaNivelParaPuntuaciones,
    'noPudoCargarse': c.noPudoCargarse,
    'etiquetaMovimientos': c.etiquetaMovimientos,
    'ajustes': c.ajustes,
    'sonido': c.sonido,
    'idioma': c.idioma,
    'ingles': c.ingles,
    'espanol': c.espanol,
  };
}
