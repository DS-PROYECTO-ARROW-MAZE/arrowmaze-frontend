import 'package:arrowmaze/presentation/views/game/confetti_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 34 — the victory confetti burst: a self-contained, presentation-only
/// overlay that fires **once** on mount and cleans its ticker up on unmount.
void main() {
  const colores = <Color>[Colors.red, Colors.green, Colors.blue];

  Widget montar(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ConfettiOverlay', () {
    testWidgets('should_start_animation_when_first_mounted', (tester) async {
      // Arrange & Act — mount the overlay and schedule its first frame.
      await tester.pumpWidget(montar(const ConfettiOverlay(colores: colores)));
      await tester.pump();

      // Assert — the burst is already running from the first mount (AC1),
      // no user tap needed.
      expect(tester.hasRunningAnimations, isTrue);

      // Drain the burst so the test ends clean.
      await tester.pumpAndSettle();
    });

    testWidgets('should_fire_only_once_across_rebuilds', (tester) async {
      // Arrange — mount and let the single burst run to completion.
      await tester.pumpWidget(montar(const ConfettiOverlay(colores: colores)));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);

      // Act — rebuild the same overlay several times (new parent frames).
      await tester.pumpWidget(montar(const ConfettiOverlay(colores: colores)));
      await tester.pump();
      await tester.pumpWidget(montar(const ConfettiOverlay(colores: colores)));
      await tester.pump();

      // Assert — the burst does not restart on rebuild: it fires once per
      // mount, not on every notifyListeners / rebuild (AC2).
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('should_dispose_controller_on_unmount', (tester) async {
      // Arrange — mount then advance into the middle of the burst.
      await tester.pumpWidget(montar(const ConfettiOverlay(colores: colores)));
      await tester.pump(const Duration(milliseconds: 100));

      // Act — remove the overlay while the burst is still playing.
      await tester.pumpWidget(montar(const SizedBox()));
      await tester.pumpAndSettle();

      // Assert — a leaked ticker makes flutter_test fail the test; reaching
      // here with the overlay gone means the controller was disposed (AC4).
      expect(find.byType(ConfettiOverlay), findsNothing);
    });
  });
}
