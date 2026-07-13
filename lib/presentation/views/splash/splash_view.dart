import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/splash_view_model.dart';

/// Full-screen branded launch screen — a thin View that only draws and animates.
///
/// It renders the ArrowMaze splash image on the very first frame (AC1), waits on
/// [SplashViewModel.listo], then plays a smooth fade-out (AC4) and invokes
/// [alCompletar] so the composition root can route to the correct screen. It
/// holds no routing and no DI: the session decision lives in the ViewModel and
/// the navigation in `main.dart`. The fade controller is disposed on unmount so
/// no ticker leaks (AC6).
class SplashView extends StatefulWidget {
  /// Creates the launch screen bound to [viewModel]; [alCompletar] fires once the
  /// fade-out finishes.
  const SplashView({
    required this.viewModel,
    required this.alCompletar,
    super.key,
  });

  /// Drives the min-visible + bootstrap wait and the post-splash routing hint.
  final SplashViewModel viewModel;

  /// Invoked once the fade-out finishes; the composition root routes from here.
  final VoidCallback alCompletar;

  /// Key of the branded image, for first-frame widget assertions.
  static const Key imagenKey = Key('splash-imagen');

  /// Key of the fade-out transition, for animation assertions (distinguishes it
  /// from route-level [FadeTransition]s in the widget tree).
  static const Key fadeKey = Key('splash-fade');

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  /// Fade-out length (opacity 1 → 0). Short so the transition feels crisp.
  static const Duration _duracionFade = Duration(milliseconds: 600);

  late final AnimationController _controlador;
  late final Animation<double> _opacidad;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _duracionFade);
    _opacidad = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controlador, curve: Curves.easeOut),
    );
    _controlador.addStatusListener((estado) {
      if (estado == AnimationStatus.completed) widget.alCompletar();
    });
    // Start the fade-out only once the minimum-visible + bootstrap wait resolves.
    widget.viewModel.listo.then((_) {
      if (mounted) _controlador.forward();
    });
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        key: SplashView.fadeKey,
        opacity: _opacidad,
        child: Center(
          child: Image.asset(
            'assets/images/ArrowMaze_splash.png',
            key: SplashView.imagenKey,
            fit: BoxFit.contain,
            // A missing/undecodable asset must never crash the launch screen.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
