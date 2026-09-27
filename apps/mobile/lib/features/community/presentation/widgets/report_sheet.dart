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
  final _formKey = GlobalKey<FormState>();
  CommunityReportReason? _reason;

  /// Le serveur compte en POINTS DE CODE ; le compteur du champ, en
  /// graphèmes. 300 cœurs emoji (U+2764 puis U+FE0F : deux points de code
  /// pour un graphème) passaient le champ (300 graphèmes) et faisaient
  /// 600 points de code : un signalement de harcèlement échouait sans dire
  /// pourquoi. On compte donc comme le serveur, AVANT l'envoi.
  ///
  /// L'emoji n'est pas écrit en toutes lettres ici : `check_mobile_fonts.py`
  /// lit tout `lib/`, commentaires compris, et exigerait alors d'Inter un
  /// glyphe que le sous-ensemble a retiré à dessein.
  static String? _validateDetails(String? value) =>
      (value?.trim().runes.length ?? 0) > communityReportDetailsMaxLength
      ? 'Tes précisions dépassent $communityReportDetailsMaxLength '
            'caractères.'
      : null;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason;
    if (reason == null || !(_formKey.currentState?.validate() ?? false)) {
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
          Form(
            key: _formKey,
            child: AppTextField(
              label: 'Précisions (facultatif)',
              controller: _details,
              hint: 'Ce qui s’est passé, en quelques mots.',
              maxLines: 3,
              maxLength: communityReportDetailsMaxLength,
              validator: _validateDetails,
            ),
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
      leading: AppIcons.report,
      leadingTint: selected ? AppColors.accent : AppColors.primaryLight,
      trailing: selected
          ? const Icon(AppIcons.check, size: 20, color: AppColors.accent)
          : null,
      onTap: onTap,
    );
  }
}
