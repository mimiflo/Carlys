import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import '../../controllers/meal_editor_controller.dart';
import '../../providers/meal_photo_provider.dart';
import '../../utils/meal_editor_state.dart';
import '../../utils/meal_editor_validation.dart';
import 'meal_editor_gestures.dart';
import 'meal_foods_card.dart';
import 'meal_identity_card.dart';
import 'meal_quantity_card.dart';
import 'meal_values_card.dart';

/// Les cartes de l'écran de repas, de haut en bas, et ses deux boutons :
/// ce que montre la maquette, sous l'en-tête.
class MealEditorForm extends ConsumerWidget {
  const MealEditorForm({
    required this.state,
    required this.controller,
    required this.gestures,
    super.key,
  });

  final MealEditorState state;
  final MealEditorController controller;
  final MealEditorGestures gestures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une case vide n'est pas une faute tant qu'on n'a pas tenté
    // d'enregistrer : les erreurs n'apparaissent qu'après.
    final errors = state.showErrors
        ? validateMealEditor(state)
        : const MealEditorErrors();
    final composed = state.isComposed;
    final photo = _photoOf(ref);
    final cards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MealIdentityCard(
          name: state.name,
          nameError: errors.name,
          moment: state.displayedMoment,
          eatenAt: state.eatenAt,
          onName: controller.setName,
          onMoment: controller.chooseMoment,
          onEatenAt: controller.setEatenAt,
          onPhoto: gestures.changePhoto,
          photo: photo.image,
          hasPhoto: state.hasPhoto,
          photoLoading: photo.loading,
          photoBusy: state.phase == MealEditorPhase.preparingPhoto,
        ),
        const SizedBox(height: AppSpacing.sm),
        MealQuantityCard(
          text: composed
              ? formatQuantityInput(state.totals.quantityG)
              : state.quantityText,
          unit: state.unit,
          computed: composed,
          error: errors.quantity,
          onText: controller.setQuantity,
          onUnit: controller.setUnit,
        ),
        const SizedBox(height: AppSpacing.sm),
        MealValuesCard(
          state: state,
          errors: errors,
          setters: (
            kcal: controller.setKcal,
            protein: controller.setProtein,
            carbs: controller.setCarbs,
            fat: controller.setFat,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        MealFoodsCard(
          lines: state.lines,
          attribution: state.attribution,
          onAdd: state.isBusy ? null : gestures.addFood,
          onQuantity: gestures.editQuantity,
          onRemove: (line) => controller.removeLine(line.id),
        ),
      ],
    );
    final sending = state.isSending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pendant un envoi, ce qui part est déjà figé : les cartes ne
        // répondent plus ni au doigt, ni au lecteur d'écran, ni au clavier
        // (le champ qui avait le focus le perd, et le clavier se ferme).
        // Une frappe acceptée alors ne serait ni envoyée ni gardée.
        ExcludeFocus(
          excluding: sending,
          child: IgnorePointer(ignoring: sending, child: cards),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCtaButton(
          label: state.isNew
              ? 'Ajouter au journal'
              : 'Enregistrer la modification',
          icon: AppIcons.check,
          isLoading: state.phase == MealEditorPhase.saving,
          loadingLabel: 'Enregistrement du repas',
          onPressed: state.isBusy
              ? null
              : () => gestures.save(isNew: state.isNew),
        ),
        if (!state.isNew) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Supprimer ce repas',
            icon: AppIcons.delete,
            variant: AppButtonVariant.destructiveOutline,
            isExpanded: true,
            isLoading: state.phase == MealEditorPhase.deleting,
            onPressed: state.isBusy ? null : gestures.delete,
          ),
        ],
      ],
    );
  }

  /// La photo que la vignette montre : la neuve, pas encore envoyée ; sinon
  /// celle du serveur, lue par le dépôt (GET authentifié) et gardée en cache
  /// sous sa date — [loading] tant qu'elle n'est pas lue ; sinon rien, et la
  /// vignette dessine le moment.
  ({ImageProvider? image, bool loading}) _photoOf(WidgetRef ref) {
    final change = state.photo;
    if (change is NewMealPhoto) {
      return (image: MemoryImage(change.jpeg), loading: false);
    }
    final savedAt = state.savedPhotoAt;
    if (savedAt == null) {
      return (image: null, loading: false);
    }
    final read = ref.watch(
      mealPhotoProvider((mealId: state.id, updatedAt: savedAt)),
    );
    final bytes = read.valueOrNull;
    return (
      image: bytes == null ? null : MemoryImage(bytes),
      loading: read.isLoading,
    );
  }
}
