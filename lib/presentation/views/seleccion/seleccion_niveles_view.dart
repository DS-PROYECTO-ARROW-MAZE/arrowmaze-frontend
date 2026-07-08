import 'package:flutter/material.dart';

import '../../../core/i18n/cadenas.dart';
import '../../../core/i18n/cadenas_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/game_theme.dart';
import '../../../domain/niveles/dificultad.dart';
import '../../viewmodels/seleccion_niveles_view_model.dart';
import '../../viewmodels/seleccion_niveles_view_state.dart';

/// Level Selection screen — a thin View that only draws (Ticket 13, DM §10.4).
///
/// Observes [SeleccionNivelesViewModel] and renders one card per level with its
/// lock affordance and star badge. Every user-facing string is read from
/// [CadenasScope] — no literals in this View (AC3). Tapping an **unlocked**
/// card calls [alSeleccionar] (injected by the composition root) to open that
/// level — the View never builds the game itself.
class SeleccionNivelesView extends StatefulWidget {
  /// Creates the level-selection screen.
  const SeleccionNivelesView({
    required this.viewModel,
    required this.alSeleccionar,
    this.onLogout,
    this.onAjustes,
    super.key,
  });

  /// The ViewModel this screen observes.
  final SeleccionNivelesViewModel viewModel;

  /// Opens [nivel]; [nivelesOrdenados] is the full ordered catalog (so the game
  /// can offer "Next level" and carry each level's backend UUID).
  final void Function(
    BuildContext context,
    NivelResumenUI nivel,
    List<NivelResumenUI> nivelesOrdenados,
  ) alSeleccionar;

  /// Called when the user taps the Logout button. The composition root wires
  /// this to clear the session and navigate back to the auth screen.
  final VoidCallback? onLogout;

  /// Called when the user taps the Settings button (AC1 — reachable after
  /// login). The composition root wires this to push [AjustesView].
  final VoidCallback? onAjustes;

  @override
  State<SeleccionNivelesView> createState() => _SeleccionNivelesViewState();
}

class _SeleccionNivelesViewState extends State<SeleccionNivelesView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_alCambiarEstado);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_alCambiarEstado);
    widget.viewModel.dispose();
    super.dispose();
  }

  void _alCambiarEstado() {}

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);

    return Scaffold(
      appBar: AppBar(
        // Level Selection is the post-login home — there is no "back" to the
        // login screen, so suppress the AppBar's automatic leading arrow.
        automaticallyImplyLeading: false,
        title: Text(s.seleccionarNivel),
        actions: [
          if (widget.onAjustes != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: s.ajustes,
              onPressed: widget.onAjustes,
            ),
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: s.cerrarSesion,
              onPressed: widget.onLogout,
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final estado = widget.viewModel.estado;

          if (estado.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (estado.mensajeError != null) {
            return Center(
              child: Text(
                estado.mensajeError!,
                style: const TextStyle(color: AppColors.errorNeon),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (estado.niveles.isEmpty) {
            return Center(
              child: Text(s.sinNiveles, style: AppTypography.bodyMedium),
            );
          }

          final ordenados = estado.niveles;
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.85,
            ),
            itemCount: estado.niveles.length,
            itemBuilder: (context, index) {
              final nivel = estado.niveles[index];
              return _NivelCard(
                nivel: nivel,
                onTap: nivel.desbloqueado
                    ? () => widget.alSeleccionar(context, nivel, ordenados)
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

/// A single level card: number, name, difficulty, and either a lock or a star
/// row. Locked cards are dimmed and non-tappable.
class _NivelCard extends StatelessWidget {
  const _NivelCard({required this.nivel, this.onTap});

  final NivelResumenUI nivel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);
    final gameTheme = Theme.of(context).extension<GameTheme>()!;
    final bloqueado = !nivel.desbloqueado;

    return Opacity(
      opacity: bloqueado ? 0.45 : 1,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(
            color: bloqueado
                ? AppColors.surfaceVariant
                : nivel.completado
                    ? AppColors.primaryNeon.withValues(alpha: 0.3)
                    : AppColors.surfaceVariant,
            width: 1.5,
          ),
        ),
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NumeroNivel(
                  numero: nivel.id,
                  completado: nivel.completado,
                  desbloqueado: nivel.desbloqueado,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  nivel.nombre,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: bloqueado
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _etiquetaDificultad(nivel.dificultad, s),
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 10,
                    color: _colorDificultad(nivel.dificultad),
                  ),
                ),
                const Spacer(),
                bloqueado
                    ? Icon(Icons.lock_outline,
                        size: 20, color: AppColors.textSecondary)
                    : _StarRow(estrellas: nivel.estrellas, gameTheme: gameTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _colorDificultad(Dificultad d) {
    return switch (d) {
      Dificultad.facil => AppColors.primaryNeon,
      Dificultad.medio => AppColors.warningNeon,
      Dificultad.dificil => AppColors.errorNeon,
    };
  }

  String _etiquetaDificultad(Dificultad d, Cadenas cadenas) {
    return switch (d) {
      Dificultad.facil => cadenas.facil,
      Dificultad.medio => cadenas.medio,
      Dificultad.dificil => cadenas.dificil,
    };
  }
}

/// The circular level-number badge; tinted when the level is completed.
class _NumeroNivel extends StatelessWidget {
  const _NumeroNivel({
    required this.numero,
    required this.completado,
    required this.desbloqueado,
  });

  final int numero;
  final bool completado;
  final bool desbloqueado;

  @override
  Widget build(BuildContext context) {
    final color = !desbloqueado
        ? AppColors.textSecondary
        : completado
            ? AppColors.primaryNeon
            : AppColors.accentNeon;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '$numero',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A row of 0–3 filled stars.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.estrellas, required this.gameTheme});

  final int estrellas;
  final GameTheme gameTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final filled = i < estrellas;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            filled ? Icons.star : Icons.star_border,
            size: 16,
            color: filled ? gameTheme.starActive : gameTheme.starInactive,
          ),
        );
      }),
    );
  }
}
