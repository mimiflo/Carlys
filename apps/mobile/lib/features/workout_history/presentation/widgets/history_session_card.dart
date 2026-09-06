import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';

/// Écart entre les colonnes de métriques (maquette).
const double _metricGap = 18;

/// Carte riche d'une séance passée : titre, date + durée en mono, pastille
/// « PR » si un record est tombé ce jour-là, puis volume et séries.
class HistorySessionCard extends StatelessWidget {
  const HistorySessionCard({
    required this.entry,
    required this.hasRecord,
    required this.onTap,
    super.key,
  });

  final WorkoutHistoryEntry entry;

  /// Un record personnel a été battu le jour de cette séance.
  final bool hasRecord;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = entry.session;
    final local = session.startedAt.toLocal();
    final duration = session.durationSeconds;
    final subtitle = duration == null
        ? formatShortDateMono(local)
        : '${formatShortDateMono(local)} · ${formatDurationShort(duration)}';
    final volume = formatVolume(entry.totalVolumeKg);
    final syncIndicator = _syncIndicator(session.syncState);

    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.listRowAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name ?? 'Séance libre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMono.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (syncIndicator != null) ...[
                const SizedBox(width: AppSpacing.xs),
                syncIndicator,
              ],
              if (hasRecord) ...[
                const SizedBox(width: AppSpacing.xs),
                const AppPill(
                  label: 'PR',
                  tone: AppPillTone.accent,
                  mono: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AppMetricColumn(
                label: 'Volume',
                value: volume.value,
                unit: volume.unit,
              ),
              const SizedBox(width: _metricGap),
              AppMetricColumn(
                label: 'Séries',
                value: formatThousands(entry.setsCount),
              ),
            ],
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.listRowAll,
        child: card,
      ),
    );
  }

  /// Séance encore en file de synchronisation, en échec, ou en conflit de
  /// clôture (à trancher depuis le détail).
  Widget? _syncIndicator(LocalSyncState state) {
    final (label, icon, color) = switch (state) {
      LocalSyncState.synced => (null, null, null),
      LocalSyncState.pending => (
        'Synchronisation en attente',
        AppIcons.offline,
        AppColors.darkTextTertiary,
      ),
      LocalSyncState.failed => (
        'Synchronisation en échec',
        AppIcons.error,
        AppColors.danger,
      ),
      LocalSyncState.conflict => (
        'Conflit de synchronisation, à trancher',
        AppIcons.error,
        AppColors.warning,
      ),
    };
    if (label == null) {
      return null;
    }

    return Semantics(
      label: label,
      child: Icon(icon, size: 16, color: color),
    );
  }
}
