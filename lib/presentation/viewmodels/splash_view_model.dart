import 'dart:async';

import '../../application/ports/proveedor_sesion.dart';

/// Thin launch-time ViewModel: decides *when* the splash may fade out and
/// *where* to route next. Pure Dart timing logic — it imports no Flutter widgets.
///
/// [listo] completes once the splash has been visible for at least
/// [minimoVisible] **and** the launch bootstrap has settled — whichever is
/// longer (AC2). The bootstrap is the auth-state probe plus an optional resource
/// warm-up, each bounded by [timeoutBootstrap] so a slow or offline start never
/// hangs the splash forever (AC3). After [listo] resolves, [haySesion] tells the
/// composition root whether to route to the menu or the login screen (AC5).
class SplashViewModel {
  /// Wires the launch bootstrap. [calentarRecursos], when provided, warms up
  /// first-run resources; it is best-effort and bounded by [timeoutBootstrap].
  SplashViewModel({
    required ProveedorSesion proveedorSesion,
    Duration minimoVisible = duracionMinimaVisible,
    Duration timeoutBootstrap = duracionTimeoutBootstrap,
    Future<void> Function()? calentarRecursos,
  })  : _proveedorSesion = proveedorSesion,
        _minimoVisible = minimoVisible,
        _timeout = timeoutBootstrap,
        _calentarRecursos = calentarRecursos {
    _listo = _arrancar();
  }

  /// Minimum time the splash stays on screen so the branding registers (~2 s).
  static const Duration duracionMinimaVisible = Duration(seconds: 2);

  /// Upper bound on any single bootstrap wait so a hung network never blocks the
  /// transition.
  static const Duration duracionTimeoutBootstrap = Duration(seconds: 5);

  final ProveedorSesion _proveedorSesion;
  final Duration _minimoVisible;
  final Duration _timeout;
  final Future<void> Function()? _calentarRecursos;

  late final Future<void> _listo;
  bool _haySesion = false;

  /// Completes when the splash may fade out: `max(minimoVisible, bootstrap)`,
  /// with every bootstrap wait bounded by the timeout (AC2/AC3).
  Future<void> get listo => _listo;

  /// Whether a session was detected during bootstrap. Meaningful only after
  /// [listo] completes; `false` when absent or when the probe timed out — a hung
  /// probe safely routes to login.
  bool get haySesion => _haySesion;

  Future<void> _arrancar() async {
    await Future.wait<void>([
      Future<void>.delayed(_minimoVisible),
      _bootstrap(),
    ]);
  }

  Future<void> _bootstrap() async {
    _haySesion = await _hayToken();
    await _calentar();
  }

  Future<bool> _hayToken() async {
    try {
      final token = await _proveedorSesion.obtenerToken().timeout(_timeout);
      return token != null;
    } catch (_) {
      // Absent or hung probe → no session (route to login).
      return false;
    }
  }

  Future<void> _calentar() async {
    final warmup = _calentarRecursos;
    if (warmup == null) return;
    try {
      await warmup().timeout(_timeout);
    } catch (_) {
      // A slow or failing warm-up must never block the transition (AC3).
    }
  }
}
