import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/game_theme.dart';
import '../../../domain/ranking/fila_ranking.dart';
import '../../viewmodels/ranking_view_state.dart';
import '../../viewmodels/ranking_view_model.dart';

/// Leaderboard screen — a thin View that only draws (DM-B5, E3).
///
/// Observes [RankingViewModel] and renders the top-N ranking rows.
/// No write path — read-only client (AC2).
class RankingView extends StatefulWidget {
  /// Creates the ranking view.
  const RankingView({required this.viewModel, super.key});

  /// The ViewModel this view observes.
  final RankingViewModel viewModel;

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onStateChanged);
    widget.viewModel.dispose();
    super.dispose();
  }

  void _onStateChanged() {}

  @override
  Widget build(BuildContext context) {
    final gameTheme = Theme.of(context).extension<GameTheme>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final estado = widget.viewModel.estado;

          return switch (estado.status) {
            RankingStatus.inicial => const Center(
                child: Text('Select a level to view scores',
                    style: AppTypography.bodyMedium),
              ),
            RankingStatus.cargando => const Center(
                child: CircularProgressIndicator(),
              ),
            RankingStatus.error => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: gameTheme.syncError),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      estado.mensajeError ?? 'Could not load leaderboard.',
                      style: const TextStyle(color: AppColors.errorNeon),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            RankingStatus.cargado => estado.entradas.isEmpty
                ? const Center(
                    child: Text('No scores yet for this level.',
                        style: AppTypography.bodyMedium),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: estado.entradas.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _RankingRow(
                      posicion: index + 1,
                      fila: estado.entradas[index],
                    ),
                  ),
          };
        },
      ),
    );
  }
}

/// A single leaderboard row — rank, player email, score, stars.
class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.posicion, required this.fila});

  /// The 1-based rank derived from the entry's position in the ordered list.
  final int posicion;
  final FilaRanking fila;

  @override
  Widget build(BuildContext context) {
    final gameTheme = Theme.of(context).extension<GameTheme>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _RankBadge(posicion: posicion),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fila.email, style: AppTypography.bodyLarge),
                  const SizedBox(height: 2),
                  _StarRow(estrellas: fila.estrellas, gameTheme: gameTheme),
                ],
              ),
            ),
            Text('${fila.puntaje}',
                style: AppTypography.hudNumber.copyWith(
                  color: gameTheme.scoreColor,
                )),
          ],
        ),
      ),
    );
  }
}

/// A circular rank badge: gold (#1), silver (#2), bronze (#3), or neutral.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.posicion});

  final int posicion;

  @override
  Widget build(BuildContext context) {
    final color = switch (posicion) {
      1 => AppColors.warningNeon,
      2 => AppColors.textSecondary,
      3 => AppColors.accentNeon,
      _ => AppColors.surfaceVariant,
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '$posicion',
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
      children: List.generate(3, (i) {
        final filled = i < estrellas;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: 16,
          color: filled ? gameTheme.starActive : gameTheme.starInactive,
        );
      }),
    );
  }
}
