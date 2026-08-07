import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../widgets/body_weight_section.dart';
import '../widgets/overview_section.dart';
import '../widgets/records_section.dart';

/// Progression : statistiques par période, records personnels, poids corporel.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Progression')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const OverviewSection(),
            const SizedBox(height: AppSpacing.lg),
            Text('Records personnels', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            const RecordsSection(),
            const SizedBox(height: AppSpacing.lg),
            Text('Poids corporel', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            const BodyWeightSection(),
          ],
        ),
      ),
    );
  }
}
