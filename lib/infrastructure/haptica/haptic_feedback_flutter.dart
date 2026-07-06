import 'package:flutter/services.dart';

import '../../application/ports/haptic_feedback_port.dart';

/// [HapticFeedbackPort] adapter backed by Flutter's [HapticFeedback].
///
/// Uses [HapticFeedback.mediumImpact] for a short, crisp buzz on an invalid
/// move. The platform call is fire-and-forget and its rejection is swallowed, so
/// on a device without a vibrator (or when the channel errors) the buzz simply
/// does nothing instead of crashing (Ticket 28, AC2).
final class HapticFeedbackFlutter implements HapticFeedbackPort {
  @override
  void vibrar() {
    // Fire-and-forget: never await, and drop any channel error so a missing
    // vibrator degrades to a silent no-op.
    HapticFeedback.mediumImpact().catchError((Object _) {});
  }
}
