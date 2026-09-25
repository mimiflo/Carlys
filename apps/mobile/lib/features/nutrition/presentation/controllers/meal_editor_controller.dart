import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/logging/app_logger.dart';
import '../../data/repositories/nutrition_repository_impl.dart';
import '../../data/services/image_picker_meal_photo_picker.dart';
import '../../domain/entities/nutrition.dart';
import '../utils/meal_editor_lines.dart';
import '../utils/meal_editor_outcome.dart';
import '../utils/meal_editor_state.dart';
import '../utils/meal_editor_validation.dart';
import 'nutrition_controllers.dart';

export '../utils/meal_editor_outcome.dart';

/// L'état d'édition d'UN repas, de son ouverture à son enregistrement.
///
/// Il lit le repas (`GET /nutrition/meals/:id`) ou en prépare un neuf, puis
/// ne fait qu'assembler ce que la personne règle. Les identifiants naissent
/// ICI, sur l'appareil : celui d'un repas neuf à l'ouverture (un
/// enregistrement raté puis rejoué garde le même, et le serveur ne fait pas
/// de doublon), celui d'une ligne d'aliment à son ajout.
///
/// Pendant un ENVOI, la saisie est ignorée : ce qui part est déjà figé.
class MealEditorController
    extends AutoDisposeFamilyAsyncNotifier<MealEditorState, MealEditorKey> {
  static const _uuid = Uuid();
  static final _logger = AppLogger('MealEditor');

  /// Une création a échoué SANS qu'on sache si le serveur l'a écrite (la
  /// réponse perdue en route) : le prochain essai relira le repas avant de
  /// l'écrire (voir `NutritionActions.addMeal`).
  bool _mayExist = false;

  @override
  Future<MealEditorState> build(MealEditorKey key) async {
    _mayExist = false;
    final mealId = key.mealId;
    if (mealId == null) {
      return MealEditorState.fresh(
        id: _uuid.v4(),
        eatenAt: initialMealInstant(key.day, DateTime.now()),
      );
    }
    final detail = await ref.watch(nutritionRepositoryProvider).meal(mealId);
    return MealEditorState.fromMeal(
      detail.meal,
      attribution: detail.attribution,
    );
  }

  MealEditorState get _state => state.requireValue;

  void _update(MealEditorState next) => state = AsyncData(next);

  /// Un geste de SAISIE. Ignoré pendant un envoi : ce qui part est déjà
  /// figé, et une frappe acceptée alors ne serait ni envoyée ni gardée.
  void _edit(MealEditorState Function(MealEditorState current) change) {
    final current = _state;
    if (!current.isSending) {
      _update(change(current));
    }
  }

  void setName(String value) => _edit((s) => s.copyWith(name: value));

  void chooseMoment(MealMoment moment) =>
      _edit((s) => s.copyWith(moment: moment));

  void setEatenAt(DateTime local) => _edit((s) => s.copyWith(eatenAt: local));

  void setUnit(MealQuantityUnit unit) => _edit((s) => s.copyWith(unit: unit));

  void setKcal(String text) => _edit((s) => s.copyWith(kcalText: text));

  void setProtein(String text) => _edit((s) => s.copyWith(proteinText: text));

  void setCarbs(String text) => _edit((s) => s.copyWith(carbsText: text));

  void setFat(String text) => _edit((s) => s.copyWith(fatText: text));

  void setQuantity(String text) => _edit((s) => s.copyWith(quantityText: text));

  /// Ajoute l'aliment [food] choisi dans la base, pour [grams] grammes, sous
  /// un UUID NEUF né sur l'appareil — qu'il gardera : c'est lui qui désigne
  /// la ligne à garder aux corrections suivantes. [source] donne la version
  /// de la table (la date que la licence exige d'afficher) et la mention.
  void addFood(Food food, double grams, FoodSource source) {
    final line = MealLine.fromFood(
      id: _uuid.v4(),
      food: food,
      quantityG: grams,
      sourceVersion: source.version,
    );
    _edit((s) => s.withLine(line, source));
  }

  /// Corrige la quantité d'une ligne (voir [MealEditorLines]).
  void setLineQuantity(String lineId, double grams) =>
      _edit((s) => s.withLineQuantity(lineId, grams));

  /// Retire une ligne ; la dernière retirée, le repas repasse à la main.
  void removeLine(String lineId) => _edit((s) => s.withoutLine(lineId));

  /// Prend ou choisit une photo, prête à l'envoi ; elle partira à
  /// l'ENREGISTREMENT. Rend `false` si la personne a renoncé. Lève
  /// [MealPhotoException] (accès refusé, image illisible) : l'écran le dit.
  Future<bool> pickPhoto(MealPhotoSource source) async {
    final current = _state;
    if (current.isBusy) {
      return false;
    }
    _update(current.copyWith(phase: MealEditorPhase.preparingPhoto));
    try {
      final jpeg = await ref.read(mealPhotoPickerProvider).pick(source);
      _update(
        _state.copyWith(
          phase: MealEditorPhase.editing,
          photo: jpeg == null ? null : NewMealPhoto(jpeg),
        ),
      );
      return jpeg != null;
    } on Exception {
      _update(_state.copyWith(phase: MealEditorPhase.editing));
      rethrow;
    }
  }

  /// Retire la photo : sur le serveur à l'enregistrement si elle y est, et
  /// tout de suite si ce n'était qu'une photo neuve pas encore envoyée.
  void removePhoto() => _edit(
    (s) => s.copyWith(
      photo: s.original?.hasPhoto ?? false
          ? const RemoveMealPhoto()
          : const KeepMealPhoto(),
    ),
  );

  /// Crée le repas neuf ou corrige l'existant, PUIS applique la photo.
  Future<MealEditorResult> save() async {
    final current = _state;
    if (current.isBusy) {
      return _busy;
    }
    if (!validateMealEditor(current).isEmpty) {
      _update(current.copyWith(showErrors: true));
      return (outcome: MealEditorOutcome.invalid, error: null);
    }
    // Le serveur refuse un repas daté du futur ; l'écran le dit AVANT
    // l'aller-retour, faute de quoi le refus arriverait sous forme d'un
    // échec qui ne nomme pas la cause.
    if (current.eatenAt.isAfter(DateTime.now())) {
      return (outcome: MealEditorOutcome.future, error: null);
    }
    _update(current.copyWith(phase: MealEditorPhase.saving));
    final actions = ref.read(nutritionActionsProvider);
    final MealEntry saved;
    try {
      final write = current.toWrite();
      saved = current.isNew
          ? await actions.addMeal(current.id, write, mayExist: _mayExist)
          : await actions.updateMeal(current.id, write);
    } on Exception catch (error) {
      _logger.warning('Repas non enregistré', error: error);
      // Une création en échec a PU être écrite (la réponse perdue en route)
      // : le prochain essai relira le repas avant de l'écrire.
      _mayExist = _mayExist || current.isNew;
      _update(current.copyWith(phase: MealEditorPhase.editing));
      return (outcome: MealEditorOutcome.failed, error: error);
    }
    try {
      await actions.applyMealPhoto(saved.id, current.photo);
      return _done;
    } on Exception catch (error) {
      // Le repas EST écrit : l'écran le rouvre tel que le serveur l'a
      // enregistré, la photo toujours en attente. Un nouvel appui corrige
      // (idempotent) puis renvoie la photo ; rien n'est perdu en silence.
      _logger.warning('Photo du repas non envoyée', error: error);
      _update(
        MealEditorState.fromMeal(
          saved,
          attribution: current.attribution,
        ).copyWith(photo: current.photo),
      );
      return (
        outcome: current.photo is RemoveMealPhoto
            ? MealEditorOutcome.photoRemovalFailed
            : MealEditorOutcome.photoFailed,
        error: error,
      );
    }
  }

  /// Supprime le repas (suppression douce ; sa photo part avec lui).
  Future<MealEditorResult> delete() async {
    final current = _state;
    if (current.isNew || current.isBusy) {
      return _busy;
    }
    _update(current.copyWith(phase: MealEditorPhase.deleting));
    try {
      await ref.read(nutritionActionsProvider).deleteMeal(current.id);
      return _done;
    } on Exception catch (error) {
      _logger.warning('Repas non supprimé', error: error);
      _update(current.copyWith(phase: MealEditorPhase.editing));
      return (outcome: MealEditorOutcome.failed, error: error);
    }
  }

  static const MealEditorResult _done = (
    outcome: MealEditorOutcome.done,
    error: null,
  );

  /// Un second appui pendant un envoi : ignoré, sans message (le premier
  /// en rendra un).
  static const MealEditorResult _busy = (
    outcome: MealEditorOutcome.busy,
    error: null,
  );
}

final mealEditorProvider = AsyncNotifierProvider.autoDispose
    .family<MealEditorController, MealEditorState, MealEditorKey>(
      MealEditorController.new,
    );
