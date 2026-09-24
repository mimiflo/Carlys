#!/usr/bin/env bash
# Aucune popup hors du design system.
#
# Demande du propriétaire, le 24 septembre 2026 : « une popup qui apparaît au
# milieu de l'écran dans le thème de l'application pour toutes les popup ».
# L'application en posait de trois sortes, chacune à sa façon : des barres de
# message Material (claires, collées en bas, hors thème), des boîtes de
# dialogue Material brutes, et des feuilles du bas qui ne servaient qu'à
# confirmer. Toutes passent désormais par une seule carte, centrée, au thème
# violet : `lib/design_system/components/`.
#
#  - message passager  → AppNotices.of(context).show(…)
#  - confirmation      → showAppConfirm(…)
#  - saisie courte     → showAppPrompt(…)
#  - toute autre forme → showAppDialog(…), qui garantit la même coquille
#
# Pourquoi un script et pas une règle de lint : l'analyseur Dart ne sait pas
# interdire un identifiant précis dans un sous-arbre précis — c'est le même
# constat que pour la banque d'icônes (check_mobile_icons.sh), et la même
# réponse.
#
# Ce que la règle protège, concrètement :
#  - **une seule apparence** : un écran qui rouvre une boîte Material
#    ramène le gris et le bandeau clair que le propriétaire a refusés ;
#  - **un seul comportement** : navigateur racine, voile, clavier, texte
#    agrandi, animations réduites, retour arrière — écrit et testé une fois
#    (test/design_system/app_notices_test.dart, app_dialogs_test.dart,
#    app_popup_test.dart), au lieu d'être réinventé, ou oublié, par écran.
set -euo pipefail

cd "$(dirname "$0")/../apps/mobile"

# `lib/design_system/` est le SEUL endroit qui a le droit d'ouvrir une popup
# par les mécaniques de Flutter — c'est lui qui les habille.
#
# Les fonctions `show…Dialog` se cherchent comme des MOTS, sans parenthèse :
# un appel générique (`showDialog<bool>(`) glisserait sinon entre les
# mailles. Les constructeurs, eux, se cherchent avec leur parenthèse, nommée
# ou non (`AlertDialog.adaptive(`, `Dialog.fullscreen(`) : c'est ce qui les
# distingue d'un simple type cité dans une signature.
#
# Les ROUTES de dialogue se cherchent aussi comme des mots : pousser soi-même
# un `DialogRoute<bool>(…)`, un `RawDialogRoute` ou un `CupertinoDialogRoute`
# ouvre la même boîte hors thème qu'un `showDialog`, sans le nommer. Même
# chose pour la feuille d'actions iOS (`showCupertinoModalPopup`, et sa route).
motif='\b(SnackBar(Action)?\(|showSnackBar|MaterialBanner\(|ScaffoldMessenger|(Alert|Simple)?Dialog(\.[A-Za-z]+)?\(|Cupertino(Alert)?Dialog\(|show(General|Cupertino|Adaptive)?Dialog\b|(Raw|Cupertino)?DialogRoute\b|CupertinoModalPopupRoute\b|showCupertinoModalPopup\b)'
fautes=$(grep -rnoE "$motif" lib --include='*.dart' \
  --exclude-dir=design_system || true)

if [ -n "$fautes" ]; then
  echo "✗ Des écrans ouvrent une popup sans passer par le design system."
  echo
  echo "$fautes" | sed 's/^/  /'
  echo
  echo "  Un message passager passe par AppNotices.of(context).show(…) —"
  echo "  capturé AVANT un await, comme l'ancien messager ; une question par"
  echo "  showAppConfirm, une saisie par showAppPrompt, toute autre forme par"
  echo "  showAppDialog (lib/design_system/components/)."
  exit 1
fi

echo "Aucun écran n'ouvre de popup à la main : tout passe par le design system."
