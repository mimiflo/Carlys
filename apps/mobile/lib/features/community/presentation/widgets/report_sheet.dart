import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/community_moderation.dart';

/// Feuille « Signaler » : un motif obligatoire (les valeurs du serveur,
/// libellées en français) et des précisions facultatives.
///
/// Rend `null` si la personne renonce. Le signalement part vers l'équipe
/// Carlys ; la personne signalée n'en sait rien, et la feuille le dit.
Future<CommunityReportDraft?> showReportSheet(
  BuildContext context, {
  required String title,
  required String subjectName,
}) {
  return showAppSheet<CommunityReportDraft>(
    context,
    builder: (_) => _ReportForm(title: title, subjectName: subjectName),
  );
}

class _ReportForm extends StatefulWidget {
  const _ReportForm({required this.title, required this.subjectName});

  final String title;
  final String subjectName;

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _details = TextEditingController();
  CommunityReportReason? _reason;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason;
    if (reason == null) {
      return;
    }
    Navigator.of(
      context,
    ).pop(CommunityReportDraft(reason: reason, details: _details.text));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: AppTypography.subheading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ton signalement part à l’équipe Carlys, en toute discrétion : '
            '${widget.subjectName} n’en saura rien.',
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppSectionLabel('Motif'),
          const SizedBox(height: AppSpacing.xs),
          for (final reason in CommunityReportReason.values) ...[
            _ReasonRow(
              reason: reason,
              selected: _reason == reason,
              onTap: () => setState(() => _reason = reason),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            label: 'Précisions (facultatif)',
            controller: _details,
            hint: 'Ce qui s’est passé, en quelques mots.',
            maxLines: 3,
            maxLength: communityReportDetailsMaxLength,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Envoyer le signalement',
            // Pas de motif, pas d'envoi : le bouton attend, il ne gronde pas.
            onPressed: _reason == null ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Annuler',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final CommunityReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: reason.label,
      leading: Icons.flag_outlined,
      leadingTint: selected ? AppColors.accent : AppColors.primaryLight,
      trailing: selected
          ? const Icon(AppIcons.check, size: 20, color: AppColors.accent)
          : null,
      onTap: onTap,
    );
  }
}
