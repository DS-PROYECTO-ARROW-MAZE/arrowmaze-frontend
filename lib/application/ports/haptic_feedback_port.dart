/// Port for one-shot tactile feedback (a short vibration), letting the
/// presentation layer buzz the device without referencing infrastructure or any
/// Flutter symbol (DIP). The concrete adapter lives in infrastructure and wraps
/// the platform's haptics; `domain`/`application` therefore stay haptics-free
/// (Ticket 28, AC3).
abstract interface class HapticFeedbackPort {
  /// Emits a brief buzz. Implementations must **degrade gracefully** — on a
  /// device without a vibrator the request is a silent no-op, never a throw
  /// (Ticket 28, AC2).
  void vibrar();
}
