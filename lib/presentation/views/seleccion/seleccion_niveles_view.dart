import 'package:flutter/material.dart';

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
/// lock affordance and star badge. Tapping an **unlocked** card calls
/// [alSeleccionar] (injected by the composition root) to open that level — the
/// View never builds the game itself.
class SeleccionNivelesView extends StatefulWidget {
  /// Creates the level-selection screen.
  const SeleccionNivelesView({
    required this.viewModel,
    required this.alSeleccionar,
    this.onLogout,
    super.key,
  });

  /// The ViewModel this screen observes.
  final SeleccionNivelesViewModel viewModel;

  /// Opens the level [idNivel]; [idsOrdenados] is the full ordered id list so the
  /// game can offer "Next level".
  final void Function(
    BuildContext context,
    int idNivel,
    List<int> idsOrdenados,
  ) alSeleccionar;

  /// Called when the user taps the Logout button. The composition root wires
  /// this to clear the session and navigate back to the auth screen.
  final VoidCallback? onLogout;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Level'),
        actions: [
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
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
            return const Center(
              child: Text('No levels available.',
                  style: AppTypography.bodyMedium),
            );
          }

          final ids = estado.niveles.map((n) => n.id).toList();
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: estado.niveles.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final nivel = estado.niveles[index];
              return _NivelCard(
                nivel: nivel,
                onTap: nivel.desbloqueado
                    ? () => widget.alSeleccionar(context, nivel.id, ids)
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
    final gameTheme = Theme.of(context).extension<GameTheme>()!;
    final bloqueado = !nivel.desbloqueado;

    return Opacity(
      opacity: bloqueado ? 0.5 : 1,
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: _NumeroNivel(numero: nivel.id, completado: nivel.completado),
          title: Text(nivel.nombre, style: AppTypography.bodyLarge),
          subtitle: Text(
            _etiquetaDificultad(nivel.dificultad),
            style: AppTypography.bodyMedium,
          ),
          trailing: bloqueado
              ? const Icon(Icons.lock_outline, color: AppColors.textSecondary)
              : _StarRow(estrellas: nivel.estrellas, gameTheme: gameTheme),
        ),
      ),
    );
  }

  String _etiquetaDificultad(Dificultad d) {
    switch (d) {
      case Dificultad.facil:
        return 'Easy';
      case Dificultad.medio:
        return 'Medium';
      case Dificultad.dificil:
        return 'Hard';
    }
  }
}

/// The circular level-number badge; tinted when the level is completed.
class _NumeroNivel extends StatelessWidget {
  const _NumeroNivel({required this.numero, required this.completado});

  final int numero;
  final bool completado;

  @override
  Widget build(BuildContext context) {
    final color = completado ? AppColors.accentNeon : AppColors.textSecondary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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
      children: List.generate(3, (i) {
        final filled = i < estrellas;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: 18,
          color: filled ? gameTheme.starActive : gameTheme.starInactive,
        );
      }),
    );
  }
}
