import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ticket 12 — Architecture guards (AC2, AC4).
///
/// Pure source-level lints wired into CI: they read the `lib/` tree and fail on
/// any import that would point the dependency arrows the wrong way. No app code
/// is executed; only `import` directives are inspected.
void main() {
  /// Returns every `import '...'` / `import "..."` target inside [dir],
  /// excluding directives that sit inside line comments.
  List<({String file, String target})> importsDe(Directory dir) {
    final directiva = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''');
    final resultado = <({String file, String target})>[];
    for (final entidad in dir.listSync(recursive: true)) {
      if (entidad is! File || !entidad.path.endsWith('.dart')) continue;
      for (final linea in entidad.readAsLinesSync()) {
        final trimmed = linea.trimLeft();
        if (trimmed.startsWith('//')) continue;
        final m = directiva.firstMatch(linea);
        if (m != null) {
          resultado.add((file: entidad.path, target: m.group(1)!));
        }
      }
    }
    return resultado;
  }

  group('Architecture — dependency direction', () {
    test('should_not_import_logging_or_metrics_library_in_decorator', () {
      // Arrange — the decorators must lean only on ports, never a concrete
      // logging/metrics/framework library (AC2).
      final dir = Directory('lib/application/decoradores');
      expect(dir.existsSync(), isTrue,
          reason: 'lib/application/decoradores must exist');

      final prohibidos = RegExp(
        r'(dart:developer|package:flutter|package:logging|package:logger|'
        r'metrics|prisma|@nestjs)',
        caseSensitive: false,
      );

      // Act / Assert
      for (final imp in importsDe(dir)) {
        expect(
          prohibidos.hasMatch(imp.target),
          isFalse,
          reason:
              '${imp.file} imports a forbidden logging/metrics/framework target: '
              '"${imp.target}" — decorators may depend only on ports (AC2).',
        );
      }
    });

    test('should_keep_domain_free_of_frameworks', () {
      // Arrange — domain stays Dart-pure: no Flutter/logging/metrics/Nest/Prisma
      // and no leakage from outer layers (AC4, ADR-0004).
      final dir = Directory('lib/domain');
      expect(dir.existsSync(), isTrue, reason: 'lib/domain must exist');

      final prohibidos = RegExp(
        r'(package:flutter|dart:ui|dart:html|package:logging|package:logger|'
        r'package:http|metrics|prisma|@nestjs|/infrastructure/|/application/|'
        r'/presentation/)',
        caseSensitive: false,
      );

      // Act / Assert
      for (final imp in importsDe(dir)) {
        expect(
          prohibidos.hasMatch(imp.target),
          isFalse,
          reason:
              '${imp.file} imports "${imp.target}", which breaks domain purity '
              '(AC4).',
        );
      }
    });
  });
}
