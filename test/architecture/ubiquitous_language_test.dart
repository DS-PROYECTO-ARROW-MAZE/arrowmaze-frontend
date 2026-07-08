import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ticket 12 — Ubiquitous-language guard (AC5).
///
/// Keeps the codebase honest to the project's agreed vocabulary by failing the
/// build if any avoid-list identifier appears in real code under `lib/`. The
/// avoid-list itself may still be *named* in dartdoc/comments (e.g. "must not
/// exist"), so full-line comments are stripped before scanning.
void main() {
  /// The forbidden identifiers (PRD §4 avoid-list). English `*Decorator`
  /// (cells) is banned in favour of the Spanish `Decorador`; the score strategy
  /// must never be time-based; the loader name stays singular.
  final prohibidos = <RegExp>[
    RegExp(r'\bCeldaSalida\b'),
    RegExp(r'\b\w*Decorator\w*\b'),
    RegExp(r'\bComposite\b'),
    RegExp(r'\bNivel(Facil|Medio|Dificil)\b'),
    RegExp(r'\bPuntuacionPorTiempo\b'),
    RegExp(r'\bCargadorNiveles\b'),
  ];

  /// Strips full-line `//` and `///` comments so the avoid-list can still be
  /// documented in dartdoc without tripping the guard.
  String codigoSinComentarios(String fuente) {
    return fuente
        .split('\n')
        .where((l) {
          final t = l.trimLeft();
          return !t.startsWith('//');
        })
        .join('\n');
  }

  group('Architecture — ubiquitous language', () {
    test('should_forbid_avoid_list_identifiers_when_scanning_lib', () {
      // Arrange
      final dir = Directory('lib');
      expect(dir.existsSync(), isTrue, reason: 'lib/ must exist');

      final infracciones = <String>[];

      // Act — scan every Dart source file under lib/.
      for (final entidad in dir.listSync(recursive: true)) {
        if (entidad is! File || !entidad.path.endsWith('.dart')) continue;
        final codigo = codigoSinComentarios(entidad.readAsStringSync());
        for (final patron in prohibidos) {
          if (patron.hasMatch(codigo)) {
            infracciones.add('${entidad.path}: ${patron.pattern}');
          }
        }
      }

      // Assert — not a single hit anywhere under lib/ (AC5).
      expect(
        infracciones,
        isEmpty,
        reason: 'Avoid-list identifiers found:\n${infracciones.join('\n')}',
      );
    });
  });
}
