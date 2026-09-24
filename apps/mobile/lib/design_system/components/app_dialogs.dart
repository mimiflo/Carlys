import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../motion/app_motion.dart';
import 'app_button.dart';
import 'app_popup_card.dart';
import 'app_popup_layout.dart';

/// LA porte des popups qui attendent une réponse : une carte centrée
/// ([AppPopupCard]) posée sur le voile de l'application.
///
/// Elle garantit ce que chaque boîte de dialogue Material réinventait, ou
/// oubliait :
///  - navigateur RACINE : ouverte depuis un onglet, la popup couvre aussi la
///    barre d'onglets flottante ;
///  - jamais sous la barre d'état ni sous le clavier, et défilable quand le
///    texte agrandi la rend plus haute que l'écran ;
///  - apparition en fondu et léger zoom, départ plus vif que l'arrivée
///    (les durées des messages passagers), le tout coupé quand le système
///    demande de réduire les animations ;
///  - un toucher sur le voile, ou le retour arrière, renonce : la future
///    rend alors `null`.
///
/// [builder] rend la carte, presque toujours un [AppPopupCard] ; ses boutons
/// referment la popup par `Navigator.of(context).pop(valeur)`. Les deux
/// formes courantes ont leur porte toute faite : [showAppConfirm] pour une
/// question, `showAppPrompt` pour une saisie.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _AppDialogRoute<T>(
      transitionDuration: AppMotion.resolve(context, AppMotion.normal),
      reverseTransitionDuration: AppMotion.resolve(context, AppMotion.fast),
      pageBuilder: (dialogContext, animation, _) => AppPopupLayout(
        child: Semantics(
          // Le nom que les lecteurs d'écran annoncent à l'ouverture, comme
          // pour une boîte de dialogue Material, et comme elle AUTOUR DE LA
          // CARTE : posé sur tout l'écran, ce nœud couvrait le voile, et un
          // toucher exploratoire à côté de la carte tombait sur lui, muet,
          // au lieu du voile « Fermer ».
          container: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: MaterialLocalizations.of(dialogContext).dialogLabel,
          child: AppPopupTransition(
            animation: animation,
            child: Builder(builder: builder),
          ),
        ),
      ),
    ),
  );
}

/// La route des popups : celle de `showGeneralDialog`, avec le voile de
/// l'application et un départ plus vif que l'arrivée.
///
/// `showGeneralDialog` ne règle que la durée d'ARRIVÉE, et une route repart
/// par défaut sur la même : une confirmation mettait donc 250 ms à partir
/// quand un message passager en met 150. D'où cette route, qui aligne les
/// deux mécaniques de la même coquille.
class _AppDialogRoute<T> extends RawDialogRoute<T> {
  _AppDialogRoute({
    required super.pageBuilder,
    required super.transitionDuration,
    required this.reverseTransitionDuration,
  }) : super(
         barrierDismissible: true,
         barrierLabel: AppPopupCard.dismissLabel,
         barrierColor: AppColors.darkScrim,
         // La transition vit DANS la page, autour de la carte seule : le
         // voile se fond de lui-même, et le zoom part du centre de la
         // carte, même quand le clavier la remonte.
         transitionBuilder: (_, _, _, child) => child,
       );

  @override
  final Duration reverseTransitionDuration;
}

/// Pose une question avant un geste, et rend la réponse.
///
/// `true` si la personne confirme ; `false` si elle renonce, touche le voile
/// ou fait retour : un geste qui supprime ne part jamais d'un doute.
///
/// [destructive] peint le bouton de confirmation en rouge (supprimer,
/// retirer, quitter) et choisit le glyphe de la corbeille ; le médaillon,
/// lui, reste violet : une question n'est pas une erreur.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Annuler',
  bool destructive = false,
  IconData? icon,
}) async {
  final confirmed = await showAppDialog<bool>(
    context,
    builder: (dialogContext) => AppPopupCard(
      icon:
          icon ??
          (destructive ? AppIcons.confirmDelete : AppIcons.confirmQuestion),
      title: title,
      message: message,
      actions: [
        AppButton(
          label: confirmLabel,
          variant: destructive
              ? AppButtonVariant.destructive
              : AppButtonVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
