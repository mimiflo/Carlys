import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_prefs.dart';
import '../../domain/mentor_word.dart';
import 'mentor_speak_button.dart';

/// La phrase « le mot du moment », pour le bouton comme pour la lecture à
/// l'ouverture de la feuille : une seule clé, un seul bouton « Arrêter ».
const String mentorWordSpeechKey = 'mentor.mot';

/// Les montagnes violettes derrière le mot : WebP 1280 × 533, qualité 92,
/// 11 Ko — plus bas, le dégradé lisse du fond se marquait en bandes.
const String mentorMountainsAsset =
    'assets/illustrations/mentor_montagnes.webp';

/// La cadence d'un mot : fête d'un cap, mot du jour ou de la semaine.
String mentorWordCadence(MentorWord mot, MentorFrequency? frequence) {
  if (mot.estCelebration) return 'Il fête un cap avec toi';
  return switch (frequence) {
    MentorFrequency.quotidienne => 'Le mot du jour',
    _ => 'Le mot de la semaine',
  };
}

/// Le bandeau du Mentor (maquette d'octobre 2026) : sa boussole, la
/// cadence de son mot, le mot lui-même et la voix qui le dit.
///
/// Le dégradé VIOLET profond du mot (`mentorWord`), texte `neutral0` : le
/// Mentor parle depuis le thème de Carlys, pas depuis une carte grise —
/// et pas depuis le dégradé de marque multicolore, réservé aux
/// célébrations de franchissement (préférence actée le 18/09/2026).
///
/// Chaque texte est en blanc PLEIN. Le surtitre et la cadence étaient à
/// 80 % : 3,18:1 au départ clair du dégradé, et encore 3,55 une fois
/// `ctaStart` assombri. La hiérarchie tient par la taille et la chasse.
class MentorBandeau extends StatelessWidget {
  const MentorBandeau({
    required this.mot,
    required this.frequence,
    this.voix,
    super.key,
  });

  /// Le mot du moment, `null` quand le Mentor se tait (interventions
  /// coupées) : le bandeau le dit au lieu d'une citation.
  final MentorWord? mot;

  final MentorFrequency? frequence;

  /// La voix qui parle (« Bienveillant »), `null` tant qu'elle n'est pas
  /// choisie : pas de pastille pour une voix qu'on n'a pas.
  final String? voix;

  @override
  Widget build(BuildContext context) {
    final mot = this.mot;
    final voix = this.voix;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.padCard),
      decoration: const BoxDecoration(
        // Le dégradé reste DESSOUS : il tient la carte tant que l'image se
        // décode, et c'est contre lui que les contrastes sont mesurés.
        gradient: AppColors.mentorWord,
        // Les montagnes de la maquette, une illustration produite dans
        // ChatGPT par le propriétaire (10 octobre 2026) : calée à droite,
        // elle garde le côté gauche, celui du texte, lisse et sombre.
        image: DecorationImage(
          image: AssetImage(mentorMountainsAsset),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.majestyBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Boussole(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (mot == null
                          ? 'Il se tait'
                          : mentorWordCadence(mot, frequence))
                      .toUpperCase(),
                  style: AppTypography.labelMono.copyWith(
                    color: AppColors.neutral0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  mot == null
                      ? 'Ses interventions sont coupées : son mot revient '
                            'quand tu les réactives.'
                      : '« ${mot.message} »',
                  style:
                      (mot == null ? AppTypography.body : AppTypography.heading)
                          .copyWith(color: AppColors.neutral0),
                ),
                if (mot != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      if (voix != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neutral0.withValues(alpha: 0.16),
                            borderRadius: AppRadius.fullAll,
                          ),
                          child: Text(
                            voix,
                            style: AppTypography.label.copyWith(
                              color: AppColors.neutral0,
                            ),
                          ),
                        ),
                      const Spacer(),
                      MentorSpeakButton(
                        speechKey: mentorWordSpeechKey,
                        text: mot.message,
                        color: AppColors.neutral0,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La boussole du guide dans son anneau, deux étincelles autour.
class _Boussole extends StatelessWidget {
  const _Boussole();

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBadgeBg,
                border: Border.all(color: AppColors.primaryLight, width: 3),
              ),
              alignment: Alignment.center,
              child: const Icon(
                AppIcons.mentor,
                size: _size * 0.56,
                color: AppColors.primaryLight,
              ),
            ),
            const Positioned(
              top: -AppSpacing.xs,
              right: -AppSpacing.xs,
              child: Icon(
                AppIcons.mentorSparkle,
                size: 20,
                color: AppColors.primaryLight,
              ),
            ),
            const Positioned(
              bottom: 0,
              left: -AppSpacing.xs,
              child: Icon(
                AppIcons.mentorSparkle,
                size: 12,
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
