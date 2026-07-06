import 'package:arrowmaze/infrastructure/haptica/haptic_feedback_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 28 (AC2) — the haptic adapter degrades gracefully on a device whose
/// vibrator is unavailable: the platform channel rejects the call, yet the buzz
/// request must be swallowed and never surface as an (unhandled) error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('should_noop_gracefully_when_haptics_unavailable', () async {
    // Arrange — simulate a device whose haptics channel rejects every call.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });
    final haptica = HapticFeedbackFlutter();

    // Act — request a buzz; the rejection happens asynchronously on the channel.
    haptica.vibrar();
    await Future<void>.delayed(Duration.zero);

    // Assert — reaching here without an unhandled exception is the guarantee.
    expect(true, isTrue);

    // Cleanup.
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}
