import 'package:flutter/material.dart';

import '../../../core/i18n/cadenas_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../viewmodels/ajustes_view_model.dart';

/// Settings screen — a thin View that only draws (Ticket 27, DM-F8).
///
/// Observes [AjustesViewModel] and renders two controls:
/// * **Sound** — a toggle switch that mutes/unmutes all SFX globally.
/// * **Language** — two mutually-exclusive chips to switch EN / ES live.
///
/// Every user-facing string is read from [CadenasScope] — no literals in this
/// View (AC3). Theme tokens from `lib/core/theme` drive all visual design.
class AjustesView extends StatefulWidget {
  /// Creates the Settings screen bound to [viewModel].
  const AjustesView({required this.viewModel, super.key});

  /// The ViewModel this screen observes and forwards actions to.
  final AjustesViewModel viewModel;

  @override
  State<AjustesView> createState() => _AjustesViewState();
}

class _AjustesViewState extends State<AjustesView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_rebuild);
    widget.viewModel.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = CadenasScope.of(context);
    final estado = widget.viewModel.estado;

    return Scaffold(
      appBar: AppBar(title: Text(s.ajustes)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.sm),

          // ── Sound toggle ─────────────────────────────────────────────────
          _AjustesCard(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              title: Text(s.sonido, style: AppTypography.bodyLarge),
              value: estado.sonidoHabilitado,
              activeColor: AppColors.primaryNeon,
              onChanged: (_) => widget.viewModel.toggleSonido(),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Language selector ─────────────────────────────────────────────
          _AjustesCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.idioma, style: AppTypography.bodyLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _IdiomaChip(
                        etiqueta: s.ingles,
                        seleccionado: estado.idioma == 'en',
                        onTap: () => widget.viewModel.cambiarIdioma('en'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _IdiomaChip(
                        etiqueta: s.espanol,
                        seleccionado: estado.idioma == 'es',
                        onTap: () => widget.viewModel.cambiarIdioma('es'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Elevated card wrapper that groups a settings row visually.
class _AjustesCard extends StatelessWidget {
  const _AjustesCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.surfaceVariant, width: 1),
      ),
      child: child,
    );
  }
}

/// A selectable language chip.
///
/// Active chips use the primary neon accent; inactive ones are muted.
class _IdiomaChip extends StatelessWidget {
  const _IdiomaChip({
    required this.etiqueta,
    required this.seleccionado,
    required this.onTap,
  });

  final String etiqueta;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = seleccionado ? AppColors.primaryNeon : AppColors.textSecondary;
    final bg = seleccionado
        ? AppColors.primaryNeon.withValues(alpha: 0.15)
        : AppColors.surfaceVariant.withValues(alpha: 0.40);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        child: Text(
          etiqueta,
          style: AppTypography.bodyLarge.copyWith(
            color: color,
            fontWeight: seleccionado ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
