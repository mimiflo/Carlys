import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/generation_report.dart';
import '../../domain/entities/training_profile.dart';
import '../controllers/program_controllers.dart';
import 'generation_report_sheet.dart';

/// Le bouton « Générer », et ce qu'il faut savoir avant de l'appuyer.
///
/// Il ne bloque rien tout seul : c'est le SERVEUR qui refuse un profil
/// incomplet, en nommant les champs manquants. Mais laisser appuyer pour
/// n'obtenir qu'un refus est une politesse qui coûte un aller-retour et une
/// déception — la carte dit donc d'avance ce qui manque, et le bouton attend.
///
/// La règle reste serveur : cet écran ne décide pas, il ANTICIPE. Si le
/// serveur refuse quand même, son message s'affiche tel quel.
class GenerateProgramCard extends ConsumerStatefulWidget {
  const GenerateProgramCard({required this.profile, super.key});

  final TrainingProfile profile;

  @override
  ConsumerState<GenerateProgramCard> createState() =>
      _GenerateProgramCardState();
}

class _GenerateProgramCardState extends ConsumerState<GenerateProgramCard> {
  bool _enCours = false;

  /// Ce qui manque, dans l'ordre où l'écran le demande — les CINQ entrées que
  /// le serveur exige, pour que les deux ne se contredisent jamais.
  ///
  /// L'objectif est lu sur CE relevé et non sur `AuthUser` : c'est celui-là
  /// que le générateur lira, et se fier à l'autre ferait dire « tout est
  /// prêt » à un écran que le serveur refuserait.
  List<String> get _manquants => [
    if (widget.profile.goal == null) 'ton objectif',
    if (widget.profile.experience == null) 'ton niveau',
    if (widget.profile.weeklySessionsTarget == null) 'tes séances par semaine',
    if (widget.profile.sessionMinutesTarget == null) 'la durée d’une séance',
    if (widget.profile.equipmentSlugs.isEmpty) 'ton matériel',
  ];

  @override
  Widget build(BuildContext context) {
    final manquants = _manquants;
    final pret = manquants.isEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // Surface sombre, et le VIOLET porté par le bouton plutôt que par le
        // fond. Un aplat violet derrière un bouton violet noie l'action dans
        // son propre bandeau : c'est ce que la première version faisait, et
        // le libellé y devenait illisible. Le liseré suffit à dire « c'est
        // ici que ça se passe ».
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.all(
          color: pret
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pret ? 'Tout est prêt' : 'Il manque encore quelque chose',
            style: AppTypography.subtitle.copyWith(
              color: pret ? AppColors.primaryLight : AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            pret
                ? 'Carlys compose ton plan à partir de tes réponses, jamais '
                      'd’un modèle générique.'
                : 'Renseigne ${_enumere(manquants)} pour lancer la génération.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Générer mon programme',
            icon: AppIcons.programs,
            isExpanded: true,
            isLoading: _enCours,
            semanticLabel: pret
                ? 'Générer mon programme'
                : 'Générer mon programme, indisponible : il manque '
                      '${_enumere(manquants)}',
            onPressed: pret && !_enCours ? _generer : null,
          ),
        ],
      ),
    );
  }

  /// « a, b et c » — une phrase, pas une liste à puces dans un paragraphe.
  String _enumere(List<String> valeurs) {
    if (valeurs.length == 1) return valeurs.first;
    return '${valeurs.sublist(0, valeurs.length - 1).join(', ')} et ${valeurs.last}';
  }

  Future<void> _generer() async {
    setState(() => _enCours = true);
    final notices = AppNotices.of(context);
    GeneratedProgramResult? resultat;
    try {
      resultat = await ref.read(programActionsProvider).generate();
    } on AppException catch (exception) {
      // Le message vient du serveur : il nomme le champ qui manque ou le
      // matériel qui débloquerait. Le réécrire ici le rendrait plus vague.
      notices.show(exception.message, tone: AppNoticeTone.error);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
    if (resultat != null && mounted) {
      await showGenerationReportSheet(context, resultat);
    }
  }
}
