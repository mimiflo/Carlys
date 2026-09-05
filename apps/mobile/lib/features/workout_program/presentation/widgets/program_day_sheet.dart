import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_template/presentation/controllers/workout_template_controllers.dart';

/// Ce qu'on peut poser sur une case du calendrier.
sealed class ProgramDayChoice {
  const ProgramDayChoice();
}

class RestDayChoice extends ProgramDayChoice {
  const RestDayChoice();
}

class TemplateDayChoice extends ProgramDayChoice {
  const TemplateDayChoice({required this.templateId, required this.name});

  final String templateId;
  final String name;
}

class FreeDayChoice extends ProgramDayChoice {
  const FreeDayChoice({required this.label});

  final String label;
}

class ClearDayChoice extends ProgramDayChoice {
  const ClearDayChoice();
}

/// Feuille d'affectation d'un jour : repos, un de MES modèles, une activité
/// libre, ou effacer la case. Rend `null` si la personne renonce.
Future<ProgramDayChoice?> showProgramDaySheet(
  BuildContext context, {
  required bool hasExisting,
}) {
  return showAppSheet<ProgramDayChoice>(
    context,
    builder: (_) => _DaySheet(hasExisting: hasExisting),
  );
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({required this.hasExisting});

  final bool hasExisting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(workoutTemplatesProvider).valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce jour-là',
            style: AppTypography.subheading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.bedtime_outlined,
              color: AppColors.primaryLight,
            ),
            title: const Text('Repos'),
            onTap: () => Navigator.of(context).pop(const RestDayChoice()),
          ),
          if (templates.isNotEmpty) ...[
            const AppSectionLabel('Mes modèles'),
            // La liste est bornée : au-delà, elle défile dans la feuille.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final template in templates)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        AppIcons.workout,
                        color: AppColors.accent,
                      ),
                      title: Text(template.name),
                      onTap: () => Navigator.of(context).pop(
                        TemplateDayChoice(
                          templateId: template.id,
                          name: template.name,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.directions_run_rounded,
              color: AppColors.primaryLight,
            ),
            title: const Text('Activité libre…'),
            onTap: () async {
              final label = await _askFreeLabel(context);
              if (label != null && context.mounted) {
                Navigator.of(context).pop(FreeDayChoice(label: label));
              }
            },
          ),
          if (hasExisting)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.backspace_outlined,
                color: AppColors.darkTextTertiary,
              ),
              title: const Text('Effacer la case'),
              onTap: () => Navigator.of(context).pop(const ClearDayChoice()),
            ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  Future<String?> _askFreeLabel(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Activité libre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Course, vélo, yoga…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final label = controller.text.trim();
              Navigator.of(dialogContext).pop(label.isEmpty ? null : label);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}
