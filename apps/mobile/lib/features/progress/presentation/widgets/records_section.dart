import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';
import 'record_row.dart';

/// Records personnels : une ligne par record, du plus récent au plus ancien.
class RecordsSection extends ConsumerWidget {
  const RecordsSection({super.key});

  /// Lignes visibles dans la page ; le reste passe par « TOUT VOIR ».
  static const int previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(personalRecordsProvider);

    return records.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: 'Records personnels'),
          SizedBox(height: AppSpacing.sm),
          AppLoadingIndicator(label: 'Chargement des records'),
        ],
      ),
      error: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(title: 'Records personnels'),
          const SizedBox(height: AppSpacing.sm),
          AppErrorState(
            title: 'Records indisponibles',
            message: AppErrorState.retryConnectionMessage,
            onRetry: () => ref.invalidate(personalRecordsProvider),
          ),
        ],
      ),
      data: (entries) => _RecordsList(records: sortedByRecency(entries)),
    );
  }

  /// Du record le plus récent au plus ancien — le premier porte l'accent.
  static List<PersonalRecordEntry> sortedByRecency(
    List<PersonalRecordEntry> entries,
  ) =>
      [...entries]..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({required this.records});

  final List<PersonalRecordEntry> records;

  @override
  Widget build(BuildContext context) {
    final preview = records.take(RecordsSection.previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Records personnels',
          trailing: records.isEmpty ? null : 'Tout voir',
          trailingTone: AppSectionTrailingTone.primary,
          onTrailingTap: records.isEmpty
              ? null
              : () => showAllRecordsSheet(context, records),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (records.isEmpty)
          const AppEmptyState(
            title: 'Aucun record pour l’instant',
            message: 'Termine une séance pour décrocher tes premiers records.',
            icon: AppIcons.record,
          )
        else
          for (final (index, record) in preview.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            RecordRow(record: record, isLatest: index == 0),
          ],
      ],
    );
  }
}

/// Liste complète des records, ouverte depuis « TOUT VOIR ».
Future<void> showAllRecordsSheet(
  BuildContext context,
  List<PersonalRecordEntry> records,
) {
  return showAppSheet<void>(
    context,
    style: AppSheetStyle.picker,
    builder: (_) => _AllRecordsSheet(records: records),
  );
}

class _AllRecordsSheet extends StatelessWidget {
  const _AllRecordsSheet({required this.records});

  final List<PersonalRecordEntry> records;

  @override
  Widget build(BuildContext context) {
    // Les marges système (haut ET bas) sont déjà prises par `showAppSheet`.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(title: 'Tous mes records'),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: records.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, index) => RecordRow(
                  record: records[index],
                  isLatest: index == 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
