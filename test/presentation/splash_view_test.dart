import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/presentation/viewmodels/splash_view_model.dart';
import 'package:arrowmaze/presentation/views/splash/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 33 — SplashView is a thin launch screen: branded image on frame 1,
/// smooth fade-out that fires a completion callback, clean ticker disposal.
void main() {
  group('SplashView', () {
    testWidgets('should_render_branded_image_on_first_frame', (tester) async {
      // Arrange — a VM that stays busy (long minimum) so the splash is on screen.
      final viewModel = SplashViewModel(
        proveedorSesion: _SesionFake(),
        minimoVisible: const Duration(seconds: 2),
        timeoutBootstrap: const Duration(seconds: 5),
      );

      // Act — pump exactly one frame.
      await tester.pumpWidget(
        MaterialApp(
          home: SplashView(viewModel: viewModel, alCompletar: () {}),
        ),
      );

      // Assert — the branded splash image renders immediately (AC1).
      expect(find.byKey(SplashView.imagenKey), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Drain the pending minimum-visible timer so the test ends clean.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('should_fade_out_and_invoke_completion_callback',
        (tester) async {
      // Arrange — bootstrap ready immediately (no session, zero minimum).
      final viewModel = SplashViewModel(
        proveedorSesion: _SesionFake(),
        minimoVisible: Duration.zero,
        timeoutBootstrap: const Duration(seconds: 5),
      );
      var completado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashView(
            viewModel: viewModel,
            alCompletar: () => completado = true,
          ),
        ),
      );

      // Act — let `listo` resolve and the fade-out run to completion.
      await tester.pumpAndSettle();

      // Assert — the callback fired after a real opacity fade (AC4), fully out.
      expect(completado, isTrue);
      final fade = tester.widget<FadeTransition>(find.byKey(SplashView.fadeKey));
      expect(fade.opacity.value, 0.0);
    });

    testWidgets('should_dispose_fade_controller_on_unmount', (tester) async {
      // Arrange — mount the splash.
      final viewModel = SplashViewModel(
        proveedorSesion: _SesionFake(),
        minimoVisible: Duration.zero,
        timeoutBootstrap: const Duration(seconds: 5),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SplashView(viewModel: viewModel, alCompletar: () {}),
        ),
      );

      // Act — replace it so the splash unmounts mid-life.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // Assert — reaching here means the AnimationController was disposed: a
      // leaked ticker makes flutter_test fail the test (AC6).
      expect(find.byType(SplashView), findsNothing);
    });
  });
}

/// A fake [ProveedorSesion] with no stored session (routing is not under test
/// here — these are View/animation tests).
class _SesionFake implements ProveedorSesion {
  @override
  Future<String?> obtenerToken() async => null;

  @override
  Future<void> guardarToken(String token) async {}

  @override
  Future<void> cerrarSesion() async {}
}
