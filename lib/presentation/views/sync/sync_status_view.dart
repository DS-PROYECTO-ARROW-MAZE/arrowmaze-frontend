import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/game_theme.dart';
import '../../viewmodels/sync_view_state.dart';

/// A compact sync-status badge shown on the game HUD (DM-B3, E2).
///
/// Displays the current sync lifecycle phase with a colour-coded icon
/// and a pending-runs count badge. Tapping triggers the onSync callback
/// (the View delegates sync to the ViewModel — never calls the use case).
///
/// Visual design uses [GameTheme] tokens (syncQueued, syncActive, syncDone,
/// syncError) so the palette stays consistent and tunable without touching
/// this widget.
class SyncStatusView extends StatelessWidget {
  /// Creates the sync status view.
  const SyncStatusView({
    required this.estado,
    required this.onSync,
    super.key,
  });

  /// The current sync view state from the ViewModel.
  final SyncViewState estado;

  /// Callback invoked when the user taps the sync button.
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final gameTheme = Theme.of(context).extension<GameTheme>()!;
    final color = _color(gameTheme);
    final icon = _icon;

    return GestureDetector(
      onTap: estado.status == SyncStatus.sincronizando ? null : onSync,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadii.cell),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (estado.pendientes > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              _Badge(count: estado.pendientes, color: color),
            ],
            if (estado.status == SyncStatus.error) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.refresh, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Color _color(GameTheme t) => switch (estado.status) {
        SyncStatus.enCola => t.syncQueued,
        SyncStatus.sincronizando => t.syncActive,
        SyncStatus.sincronizado => t.syncDone,
        SyncStatus.error => t.syncError,
      };

  IconData get _icon => switch (estado.status) {
        SyncStatus.enCola => Icons.cloud_off,
        SyncStatus.sincronizando => Icons.cloud_sync,
        SyncStatus.sincronizado => Icons.cloud_done,
        SyncStatus.error => Icons.cloud_off,
      };
}

/// A small numeric badge showing the pending-runs count.
class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color.computeLuminance() > 0.5
              ? const Color(0xFF1A1A24)
              : const Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
