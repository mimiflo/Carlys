import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import '../../../domain/meal_bounds.dart';
import 'bound_text.dart';
import 'meal_icons.dart';
import 'meal_when_row.dart';

/// La première carte de l'écran : QUEL repas. La photo du plat, son nom, le
/// moment de la journée et l'instant où il a été mangé.
class MealIdentityCard extends StatelessWidget {
  const MealIdentityCard({
    required this.name,
    required this.nameError,
    required this.moment,
    required this.eatenAt,
    required this.onName,
    required this.onMoment,
    required this.onEatenAt,
    required this.onPhoto,
    this.photo,
    this.hasPhoto = false,
    this.photoLoading = false,
    this.photoBusy = false,
    super.key,
  });

  final String name;
  final String? nameError;

  /// Le moment AFFICHÉ : le choisi, ou celui que l'heure propose.
  final MealMoment moment;
  final DateTime eatenAt;
  final ValueChanged<String> onName;
  final ValueChanged<MealMoment> onMoment;
  final ValueChanged<DateTime> onEatenAt;

  /// Le bouton appareil photo de la vignette.
  final VoidCallback onPhoto;

  /// Les octets de la photo du plat, quand elle existe et qu'ils sont lus.
  /// Sans elle, la vignette violette dessinée, au moment du repas.
  final ImageProvider? photo;

  /// Le repas A une photo, lue ou non : c'est elle, et non la présence des
  /// octets, qui dit ce que la vignette annonce. Une photo pas encore lue
  /// (réseau lent, hors connexion) n'est pas une photo absente.
  final bool hasPhoto;

  /// Les octets d'une photo du serveur se lisent : la vignette attend.
  final bool photoLoading;

  /// Une photo neuve se prépare (redressée, réduite) : la vignette attend.
  final bool photoBusy;

  /// La largeur sous laquelle une tuile de moment ne descend pas : quatre
  /// sur une rangée de téléphone, deux sur 320 points ou en grand texte.
  static const double _momentTileWidth = 64;

  /// La largeur de carte, en points de texte, sous laquelle le nom passe
  /// sous la photo.
  static const double _sideBySideWidth = 240;

  /// Ce que la vignette dit au lecteur d'écran : la photo, son absence, ou
  /// une photo qui existe mais ne se montre pas (encore).
  String get _photoLabel {
    if (photo != null) {
      return 'Photo du plat';
    }
    if (!hasPhoto) {
      return 'Pas encore de photo du plat';
    }
    return photoLoading
        ? 'Photo du plat, en chargement'
        : 'Photo du plat, indisponible pour l’instant';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final thumbnail = AppThumbnail(
                image: photo,
                busy: photoBusy,
                loading: photoLoading,
                busyLabel: photoBusy
                    ? 'Préparation de la photo'
                    : 'Chargement de la photo du plat',
                fallbackIcon: moment.icon,
                semanticLabel: _photoLabel,
                action: AppThumbnailAction(
                  icon: AppIcons.mealPhoto,
                  tooltip: hasPhoto || photo != null
                      ? 'Changer la photo'
                      : 'Ajouter une photo',
                  onPressed: onPhoto,
                ),
              );
              final field = BoundText(
                text: name,
                builder: (controller) => AppTextField(
                  label: 'Nom du repas',
                  controller: controller,
                  hint: 'Poulet, riz, brocoli',
                  suffixIcon: AppIcons.editOutline,
                  suffixIconColor: AppColors.primaryLight,
                  // Sur une ligne, « Poulet, riz, brocoli » se coupait sous
                  // le crayon : le nom passe à la ligne et se lit en entier.
                  // Clavier de TEXTE, pas multiligne : un nom n'a pas de
                  // retour à la ligne, la touche passe au champ suivant.
                  keyboardType: TextInputType.text,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  maxLength: MealBounds.nameMaxLength,
                  errorText: nameError,
                  onChanged: onName,
                ),
              );
              // Le nom à côté de la photo, comme la maquette, tant qu'il y a
              // la place de le lire ; dessous sinon (320 points, grand
              // texte), plutôt qu'un champ où trois lettres tiennent.
              final side =
                  constraints.maxWidth >=
                  MediaQuery.textScalerOf(context).scale(_sideBySideWidth);
              if (!side) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumbnail,
                    const SizedBox(height: AppSpacing.md),
                    field,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  thumbnail,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: field),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          // Le libellé et sa grille, d'un seul groupe : le lecteur d'écran
          // annonce « Moment de la journée » en y entrant, et non plus dans
          // un bloc de libellés détachés de leurs contrôles.
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'Moment de la journée',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Text(
                    'Moment de la journée',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppAdaptiveGrid(
                  minItemWidth: _momentTileWidth,
                  children: [
                    for (final value in MealMoment.values)
                      AppIconChoiceTile(
                        icon: value.icon,
                        label: value.label,
                        selected: value == moment,
                        onTap: () => onMoment(value),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          MealWhenRow(eatenAt: eatenAt, onChanged: onEatenAt),
        ],
      ),
    );
  }
}
