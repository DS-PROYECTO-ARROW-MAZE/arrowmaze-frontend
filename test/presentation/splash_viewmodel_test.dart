import 'dart:async';

import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/presentation/viewmodels/splash_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 33 — SplashViewModel owns the launch timing (min-visible + bootstrap,
/// each bounded by a timeout) and the post-splash routing hint. Pure Dart logic
/// driven through a fake clock and a fake session probe — no Flutter, no assets.
void main() {
  group('SplashViewModel', () {
    test('should_complete_after_minimum_visible_even_if_bootstrap_is_instant',
        () {
      fakeAsync((async) {
        // Arrange — no session (probe resolves instantly), 2 s minimum visible.
        final viewModel = SplashViewModel(
          proveedorSesion: _SesionFake(),
          minimoVisible: const Duration(seconds: 2),
          timeoutBootstrap: const Duration(seconds: 5),
        );
        var completo = false;
        viewModel.listo.then((_) => completo = true);

        // Act & Assert — still visible just before the minimum elapses...
        async.elapse(const Duration(milliseconds: 1999));
        expect(completo, isFalse);

        // ...and ready once the minimum passes (AC2).
        async.elapse(const Duration(milliseconds: 2));
        expect(completo, isTrue);
      });
    });

    test('should_wait_for_bootstrap_when_slower_than_minimum', () {
      fakeAsync((async) {
        // Arrange — the probe resolves at 3 s, past the 2 s minimum.
        final viewModel = SplashViewModel(
          proveedorSesion:
              _SesionFake(token: 'tok', retraso: const Duration(seconds: 3)),
          minimoVisible: const Duration(seconds: 2),
          timeoutBootstrap: const Duration(seconds: 5),
        );
        var completo = false;
        viewModel.listo.then((_) => completo = true);

        // Act & Assert — minimum passed but bootstrap still running...
        async.elapse(const Duration(seconds: 2));
        expect(completo, isFalse);

        // ...done only once bootstrap resolves (AC2).
        async.elapse(const Duration(seconds: 1));
        expect(completo, isTrue);
        expect(viewModel.haySesion, isTrue);
      });
    });

    test('should_complete_within_timeout_when_resources_hang', () {
      fakeAsync((async) {
        // Arrange — a probe that never resolves; the 5 s timeout must rescue it.
        final viewModel = SplashViewModel(
          proveedorSesion: _SesionColgada(),
          minimoVisible: const Duration(seconds: 2),
          timeoutBootstrap: const Duration(seconds: 5),
        );
        var completo = false;
        viewModel.listo.then((_) => completo = true);

        // Act — advance to the bootstrap timeout.
        async.elapse(const Duration(seconds: 5));

        // Assert — the splash transitions instead of hanging forever (AC3), and a
        // hung probe is treated as "no session" (safe default → login).
        expect(completo, isTrue);
        expect(viewModel.haySesion, isFalse);
      });
    });

    test('should_route_to_menu_when_session_present_and_login_otherwise', () {
      fakeAsync((async) {
        // Arrange — one VM with a stored token, one without.
        final conSesion = SplashViewModel(
          proveedorSesion: _SesionFake(token: 'tok'),
          minimoVisible: const Duration(seconds: 2),
          timeoutBootstrap: const Duration(seconds: 5),
        );
        final sinSesion = SplashViewModel(
          proveedorSesion: _SesionFake(),
          minimoVisible: const Duration(seconds: 2),
          timeoutBootstrap: const Duration(seconds: 5),
        );

        // Act — let both finish bootstrap and the minimum wait.
        async.elapse(const Duration(seconds: 2));

        // Assert — session present routes to the menu; absent routes to login (AC5).
        expect(conSesion.haySesion, isTrue);
        expect(sinSesion.haySesion, isFalse);
      });
    });
  });
}

/// A fake [ProveedorSesion] returning [token] after an optional [retraso].
class _SesionFake implements ProveedorSesion {
  _SesionFake({this.token, this.retraso = Duration.zero});

  final String? token;
  final Duration retraso;

  @override
  Future<String?> obtenerToken() async {
    if (retraso > Duration.zero) await Future<void>.delayed(retraso);
    return token;
  }

  @override
  Future<void> guardarToken(String token) async {}

  @override
  Future<void> cerrarSesion() async {}
}

/// A [ProveedorSesion] whose probe never resolves — models a hung network read.
class _SesionColgada implements ProveedorSesion {
  @override
  Future<String?> obtenerToken() => Completer<String?>().future;

  @override
  Future<void> guardarToken(String token) async {}

  @override
  Future<void> cerrarSesion() async {}
}
