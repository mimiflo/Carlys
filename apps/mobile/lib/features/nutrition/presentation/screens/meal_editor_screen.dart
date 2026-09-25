import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../controllers/meal_editor_controller.dart';
import '../utils/meal_editor_state.dart';
import '../widgets/meal_editor/meal_editor_form.dart';
import '../widgets/meal_editor/meal_editor_gestures.dart';

/// AJOUTER ou MODIFIER un repas, en plein écran — d'après la maquette
/// « Modifier ce repas » du 25 septembre 2026.
///
/// UN seul écran pour les deux gestes, parce que ce sont les mêmes champs,
/// les mêmes bornes et les mêmes pièges : deux copies, ce serait deux
/// endroits où corriger la borne des calories. [mealId] nul, on ajoute un
/// repas daté de [day] (le jour qu'affiche le journal) ; sinon, on relit le
/// repas sur le serveur (`GET /nutrition/meals/:id`) et on le corrige sur
/// place.
class MealEditorScreen extends ConsumerWidget {
  const MealEditorScreen({this.mealId, this.day, super.key});

  final String? mealId;
  final DateTime? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (mealId: mealId, day: day);
    final provider = mealEditorProvider(key);
    final editor = ref.watch(provider);
    final state = editor.valueOrNull;
    final gestures = MealEditorGestures(context, ref, key);

    final Widget body;
    if (state != null) {
      body = MealEditorForm(
        state: state,
        controller: ref.read(provider.notifier),
        gestures: gestures,
      );
    } else if (editor.hasError) {
      body = _Unavailable(
        error: editor.error!,
        onRetry: () => ref.invalidate(provider),
      );
    } else {
      body = const AppLoadingIndicator(label: 'Chargement du repas');
    }

    final padding = MediaQuery.paddingOf(context);
    // Pendant un envoi, le retour est RETENU : l'écran se refermera de
    // lui-même à la réponse, et un retour accepté maintenant ferait dépiler,
    // à la réponse, la page du dessous.
    return PopScope(
      canPop: !(state?.isSending ?? false),
      child: AppDarkScaffold(
        // Une colonne défilante plutôt qu'une liste paresseuse : quatre cartes
        // et deux boutons, tous construits d'emblée — un champ qui prend le
        // focus ou une erreur à montrer peuvent ainsi toujours être amenés à
        // l'écran.
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            padding.top + AppSpacing.md,
            AppSpacing.md,
            padding.bottom + AppSpacing.gapSection,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                // Un repas neuf déjà ENREGISTRÉ (sa photo n'est pas partie, et
                // l'écran reste ouvert pour la renvoyer) se modifie désormais.
                isNew: state?.isNew ?? mealId == null,
                state: state,
                onDelete: gestures.delete,
              ),
              const SizedBox(height: AppSpacing.md),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

/// « Modifier ce repas / AJUSTE LES DÉTAILS », la corbeille à droite ; pour
/// un repas neuf, rien à supprimer, donc pas de corbeille.
class _Header extends StatelessWidget {
  const _Header({
    required this.isNew,
    required this.state,
    required this.onDelete,
  });

  final bool isNew;

  /// `null` tant que le repas n'est pas lu : la corbeille attend.
  final MealEditorState? state;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final loaded = state;
    return AppScreenHeader.centered(
      title: isNew ? 'Nouveau repas' : 'Modifier ce repas',
      tagline: isNew ? 'Note ce que tu as mangé' : 'Ajuste les détails',
      actions: [
        if (!isNew && loaded != null)
          AppRoundIconButton(
            icon: AppIcons.delete,
            tooltip: 'Supprimer ce repas',
            color: AppColors.danger,
            // Pendant un envoi, désactivée comme le bouton du bas : les deux
            // portes du même geste disent la même chose.
            onPressed: loaded.isBusy ? null : onDelete,
          ),
      ],
    );
  }
}

/// Le repas n'a pas pu être lu : il n'existe plus (supprimé, ou pas à
/// soi), ou le réseau et le serveur ont manqué.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final gone = switch (error) {
      ServerException(statusCode: 404) => true,
      _ => false,
    };
    if (gone) {
      return AppEmptyState(
        icon: AppIcons.nutrition,
        title: 'Ce repas n’est plus là',
        message:
            'Il a été supprimé, peut-être depuis un autre appareil. Ton '
            'journal t’attend avec le reste de ta journée.',
        actionLabel: 'Retour au journal',
        onAction: () => Navigator.of(context).maybePop(),
      );
    }
    return ConnectionAwareError(
      error: error,
      title: 'Repas indisponible',
      message: 'Le repas n’a pas pu être chargé. Réessaie.',
      offlineMessage:
          'Le journal vit sur le serveur : ce repas revient avec le réseau.',
      onRetry: onRetry,
    );
  }
}
