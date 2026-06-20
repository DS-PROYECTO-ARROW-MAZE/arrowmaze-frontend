import 'package:flutter_test/flutter_test.dart';

import 'package:arrowmaze/infrastructure/sesion/proveedor_sesion_impl.dart';

/// Ticket 08 — RED phase: ProveedorSesionImpl (AC4).
///
/// Tests the concrete in-memory session storage.
void main() {
  group('ProveedorSesionImpl (AC4)', () {
    test(
      'should_clear_token_when_cerrarSesion',
      () async {
        // Arrange — store a token first.
        final sesion = ProveedorSesionImpl();
        await sesion.guardarToken('tok-xyz');
        expect(await sesion.obtenerToken(), 'tok-xyz');

        // Act
        await sesion.cerrarSesion();

        // Assert — the token is gone.
        expect(await sesion.obtenerToken(), isNull);
      },
    );

    test(
      'should_return_null_when_no_token_stored',
      () async {
        // Arrange
        final sesion = ProveedorSesionImpl();

        // Act + Assert
        expect(await sesion.obtenerToken(), isNull);
      },
    );

    test(
      'should_overwrite_previous_token_when_guardarToken_called_twice',
      () async {
        // Arrange
        final sesion = ProveedorSesionImpl();
        await sesion.guardarToken('tok-old');
        await sesion.guardarToken('tok-new');

        // Assert — the latest token is returned.
        expect(await sesion.obtenerToken(), 'tok-new');
      },
    );
  });
}
