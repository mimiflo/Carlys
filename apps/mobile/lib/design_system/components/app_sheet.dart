import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';

/// Les deux familles de feuilles de la maquette : formulaire (surface
/// standard, angles `lg`) et sélecteur (surface alternative, angles
/// `cardMain`).
enum AppSheetStyle { form, picker }

/// LA porte d'entrée des feuilles modales de l'application.
///
/// Elle garantit ce que chaque feuille réinventait — ou oubliait :
///  - navigateur RACINE : ouverte depuis un onglet, une feuille passerait
///    sinon SOUS la bottom bar flottante, qui masquerait son bouton ;
///  - le clavier ne recouvre jamais les champs (`viewInsets`) ;
///  - le contenu s'arrête AU-DESSUS de la barre système du téléphone
///    (SafeArea bas) : le bouton de validation reste atteignable sur les
///    appareils à barre de navigation 3 boutons comme à geste ;
///  - jamais sous la barre d'état en haut (`useSafeArea`).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  AppSheetStyle style = AppSheetStyle.form,
}) {
  final form = style == AppSheetStyle.form;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: form ? AppColors.darkSurface : AppColors.darkSurfaceAlt,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(form ? AppRadius.lg : AppRadius.cardMain),
      ),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(top: false, child: Builder(builder: builder)),
    ),
  );
}
