import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 11 — RED phase: Architecture guard (AC2).
///
/// Asserts the ranking port is strictly read-only by checking the source file
/// contains no `publicar` declaration. A pure source-level lint check.
void main() {
  group('Ranking architecture — read-only port', () {
    test(
      'should_have_no_publicar_method_on_ranking_port',
      () {
        // Arrange — locate the port interface source file.
        final file = File('lib/application/ports/i_consulta_ranking.dart');

        // Assert — the file must exist.
        expect(file.existsSync(), isTrue,
            reason: 'IConsultaRanking port file must exist');

        // Assert — the source must NOT contain a `publicar` declaration.
        // We check for method-like declarations (not inside comments).
        final source = file.readAsStringSync();
        final lines = source.split('\n');
        final codeLines = lines
            .where((l) => !l.trim().startsWith('//') && !l.trim().startsWith('///'))
            .join('\n');

        expect(
          RegExp(r'\bpublicar\b').hasMatch(codeLines),
          isFalse,
          reason:
              'IConsultaRanking must NOT declare a publicar() method (AC2 — read-only)',
        );
      },
    );

    test(
      'should_have_only_obtenerTop_method_on_ranking_port',
      () {
        // Arrange
        final file = File('lib/application/ports/i_consulta_ranking.dart');

        final source = file.readAsStringSync();

        // Count Future/async method declarations in the interface body.
        final methodPattern = RegExp(r'Future<\w+>\s+\w+\s*\(');
        final matches = methodPattern.allMatches(source).toList();

        expect(matches.length, 1,
            reason:
                'IConsultaRanking must have exactly one method (obtenerTop), found ${matches.length}');

        expect(source.contains('obtenerTop'), isTrue,
            reason: 'IConsultaRanking must declare obtenerTop');
      },
    );
  });
}
