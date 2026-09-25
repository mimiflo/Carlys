import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/feedback/server_gesture.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import '../../controllers/meal_editor_controller.dart';
import '../../utils/meal_editor_state.dart';
import '../../utils/meal_editor_validation.dart';
import 'meal_food_picker.dart';
import 'meal_photo_flow.dart';

/// Les GESTES de l'écran de repas qui dépassent la simple frappe : ils
/// posent une question, parlent au serveur, puis disent ce qu'il advient.
///
/// Réunis ici pour que l'écran ne fasse que se dessiner : chaque geste
/// capture ses messagers AVANT d'attendre (l'écran peut se refermer
/// entre-temps), et aucun ne touche au réseau autrement que par le
/// contrôleur.
class MealEditorGestures {
  const MealEditorGestures(this._context, this._ref, this._key);

  final BuildContext _context;
  final WidgetRef _ref;
  final MealEditorKey _key;

  MealEditorController get _controller =>
      _ref.read(mealEditorProvider(_key).notifier);

  /// Enregistre, puis revient au journal ; sinon, dit pourquoi.
  Future<void> save({required bool isNew}) async {
    final notices = AppNotices.of(_context);
    final navigator = Navigator.of(_context);
    final result = await _controller.save();
    final done = isNew ? 'Repas ajouté' : 'Repas modifié';
    final offline = _offline(result.error) ? ' (hors connexion)' : '';
    switch (result.outcome) {
      case MealEditorOutcome.done:
        notices.show(
          isNew ? 'Repas ajouté au journal.' : 'Repas modifié.',
          tone: AppNoticeTone.success,
        );
        _leave(navigator);
      case MealEditorOutcome.photoFailed:
        // Le repas EST enregistré ; seule la photo manque. L'écran reste
        // ouvert, la photo en attente : un nouvel appui la renvoie.
        notices.show(
          '$done, mais la photo n’est pas partie$offline. Touche '
          '« Enregistrer la modification » pour la renvoyer.',
          tone: AppNoticeTone.error,
        );
      case MealEditorOutcome.photoRemovalFailed:
        // La photo est TOUJOURS sur le serveur : rien n'est à « renvoyer »,
        // c'est le retrait qui reste à faire.
        notices.show(
          '$done, mais la photo n’a pas pu être retirée$offline. Touche '
          '« Enregistrer la modification » pour réessayer.',
          tone: AppNoticeTone.error,
        );
      case MealEditorOutcome.invalid:
        notices.show(
          'Il manque quelque chose : vérifie les cases signalées en rouge.',
          tone: AppNoticeTone.error,
        );
      case MealEditorOutcome.future:
        notices.show(
          'On ne mange pas demain : choisis un moment passé.',
          tone: AppNoticeTone.error,
        );
      case MealEditorOutcome.failed:
        // Le repas n'est PAS enregistré, et l'écran reste ouvert avec tout
        // ce qui a été saisi : rien n'est perdu, il suffit de réessayer.
        notices.show(_failure(result.error), tone: AppNoticeTone.error);
      case MealEditorOutcome.busy:
        break;
    }
  }

  /// Demande, puis supprime et revient au journal.
  Future<void> delete() async {
    final notices = AppNotices.of(_context);
    final navigator = Navigator.of(_context);
    final confirmed = await showAppConfirm(
      _context,
      title: 'Supprimer ce repas ?',
      message:
          'Il disparaîtra de ton journal et des totaux de sa journée. '
          'Cette suppression ne se défait pas.',
      confirmLabel: 'Supprimer',
      cancelLabel: 'Garder ce repas',
      destructive: true,
    );
    // Renoncé, ou l'écran s'est refermé pendant la question.
    if (!confirmed || !_context.mounted) {
      return;
    }
    final result = await _controller.delete();
    switch (result.outcome) {
      case MealEditorOutcome.done:
        notices.show('Repas supprimé.', tone: AppNoticeTone.success);
        _leave(navigator);
      case MealEditorOutcome.failed:
        notices.show(_failure(result.error), tone: AppNoticeTone.error);
      case MealEditorOutcome.photoFailed ||
          MealEditorOutcome.photoRemovalFailed ||
          MealEditorOutcome.invalid ||
          MealEditorOutcome.future ||
          MealEditorOutcome.busy:
        break;
    }
  }

  /// Corrige la quantité d'un aliment, dans une popup de saisie numérique.
  Future<void> editQuantity(MealLine line) async {
    final raw = await showAppPrompt(
      _context,
      title: 'Quantité de ${line.shortName}',
      message: 'En grammes, de 1 à 5 000.',
      initialValue: formatQuantityInput(line.quantityG),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      suffixText: 'g',
      icon: AppIcons.mealQuantity,
      validator: componentQuantityError,
    );
    final grams = raw == null ? null : parseDecimalInput(raw);
    if (grams == null || !_context.mounted) {
      return;
    }
    _controller.setLineQuantity(line.id, grams);
  }

  /// Referme l'écran — S'IL est encore là. Le retour est retenu pendant un
  /// envoi, mais une navigation venue d'ailleurs (une notification) peut
  /// l'avoir refermé entre-temps : dépiler alors ôterait la page du
  /// dessous. Le message, lui, s'affiche quand même.
  void _leave(NavigatorState navigator) {
    if (_context.mounted) {
      navigator.pop();
    }
  }

  Future<void> addFood() => pickFoodForMeal(_context, _ref, _key);

  Future<void> changePhoto() => pickMealPhoto(_context, _ref, _key);

  static String _failure(Object? error) =>
      serverFailureMessage(error is AppException ? error : null);

  static bool _offline(Object? error) => error is NetworkException;
}
