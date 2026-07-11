import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A self-contained, **presentation-only** confetti burst for the victory screen
/// (Ticket 34).
///
/// It owns a single [AnimationController] (via a [TickerProvider]) and paints a
/// shower of falling particles with a [CustomPainter] — the same hand-rolled
/// idiom as the board's other painters (`_RelojHud`, `_SalidaPainter`), so the
/// project needs **no** new animation/particle package. The burst **fires once**
/// in [State.initState] and never restarts on rebuilds, so it plays exactly once
/// per mount (one win) rather than on every `notifyListeners`. The controller is
/// disposed on unmount, leaking no ticker if the screen closes mid-burst.
///
/// It reads nothing from the ViewModel or the domain — it is handed only a list
/// of [colores] to tint the particles — so it stays purely decorative and never
/// drives game logic. It is wrapped in an [IgnorePointer] so it can never
/// intercept the victory panel's Next / Retry / Menu buttons.
class ConfettiOverlay extends StatefulWidget {
  /// Creates a confetti burst whose particles are tinted from [colores].
  const ConfettiOverlay({
    required this.colores,
    this.cantidadParticulas = _cantidadParticulasPorDefecto,
    this.duracion = _duracionPorDefecto,
    this.gravedad = _gravedadPorDefecto,
    super.key,
  });

  /// How many particles the burst throws.
  static const int _cantidadParticulasPorDefecto = 90;

  /// How long the whole burst lasts before settling.
  static const Duration _duracionPorDefecto = Duration(milliseconds: 1600);

  /// Downward acceleration applied over the burst, in normalized board heights
  /// (so it scales with any screen size).
  static const double _gravedadPorDefecto = 1.4;

  /// The palette the particles are tinted from (cycled through).
  final List<Color> colores;

  /// How many particles to throw.
  final int cantidadParticulas;

  /// How long the burst plays.
  final Duration duracion;

  /// Downward acceleration over the burst (normalized units).
  final double gravedad;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final List<_Particula> _particulas;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: widget.duracion);
    _particulas = _sembrarParticulas();
    // Fire once on mount: winning triggers the celebration with no user tap and
    // without re-firing on later rebuilds (the controller is only started here).
    _controlador.forward();
  }

  /// Seeds the fixed particle field once: each particle gets a start point along
  /// the top, an initial velocity (sideways spread + downward toss), a colour and
  /// a spin. The painter then evolves these deterministically from `t`, so no
  /// per-frame allocation or randomness leaks into the render loop.
  List<_Particula> _sembrarParticulas() {
    final azar = math.Random(_semilla);
    return List<_Particula>.generate(widget.cantidadParticulas, (i) {
      return _Particula(
        inicioX: azar.nextDouble(),
        inicioY: -0.1 * azar.nextDouble(),
        velocidadX: (azar.nextDouble() - 0.5) * 0.6,
        velocidadY: 0.2 + azar.nextDouble() * 0.5,
        color: widget.colores[i % widget.colores.length],
        tamano: 0.012 + azar.nextDouble() * 0.014,
        giro: azar.nextDouble() * math.pi,
        velocidadGiro: (azar.nextDouble() - 0.5) * 8,
      );
    });
  }

  /// Fixed seed so the shower looks the same each win (and is deterministic in
  /// tests) while still reading as a scattered, organic burst.
  static const int _semilla = 34;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Purely decorative: never intercept taps meant for the panel buttons (AC5).
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controlador,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              particulas: _particulas,
              t: _controlador.value,
              gravedad: widget.gravedad,
            ),
          ),
        ),
      ),
    );
  }
}

/// One confetti particle: its launch point, velocity, colour and spin, all in
/// normalized [0, 1] board space so the painter can scale them to any size.
class _Particula {
  const _Particula({
    required this.inicioX,
    required this.inicioY,
    required this.velocidadX,
    required this.velocidadY,
    required this.color,
    required this.tamano,
    required this.giro,
    required this.velocidadGiro,
  });

  /// Horizontal launch position (0 = left edge, 1 = right edge).
  final double inicioX;

  /// Vertical launch position (slightly above the top so pieces enter falling).
  final double inicioY;

  /// Initial horizontal velocity (normalized units per unit `t`).
  final double velocidadX;

  /// Initial downward velocity (normalized units per unit `t`).
  final double velocidadY;

  /// The particle's colour.
  final Color color;

  /// The particle's side length as a fraction of the board width.
  final double tamano;

  /// Initial rotation (radians).
  final double giro;

  /// Angular velocity (radians per unit `t`), so pieces tumble as they fall.
  final double velocidadGiro;
}

/// Paints the particle field for a given progress [t] (0 → 1). It is deliberately
/// *dumb*: position and fade are pure functions of `t`, so the celebration's look
/// lives entirely here with no state and no per-frame allocation of geometry.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particulas,
    required this.t,
    required this.gravedad,
  });

  final List<_Particula> particulas;
  final double t;
  final double gravedad;

  @override
  void paint(Canvas canvas, Size size) {
    // Fade the whole shower out over the final third so it never lingers.
    final opacidad = (1.0 - ((t - 0.66) / 0.34)).clamp(0.0, 1.0);
    if (opacidad <= 0) return;
    final pintura = Paint()..style = PaintingStyle.fill;

    for (final p in particulas) {
      // Simple projectile motion: constant horizontal drift, gravity-accelerated
      // fall. Everything is in normalized units, scaled to pixels below.
      final x = (p.inicioX + p.velocidadX * t) * size.width;
      final y =
          (p.inicioY + p.velocidadY * t + 0.5 * gravedad * t * t) * size.height;
      final lado = p.tamano * size.width;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.giro + p.velocidadGiro * t);
      pintura.color = p.color.withValues(alpha: opacidad);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: lado, height: lado * 0.6),
        pintura,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.t != t ||
      old.gravedad != gravedad ||
      !identical(old.particulas, particulas);
}
