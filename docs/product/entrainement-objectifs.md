# Objectif d'entraînement (Plan 4)

## Deux axes, deux questions

L'objectif d'ENTRAÎNEMENT (`TrainingGoal`) dit **pourquoi on s'entraîne** ;
l'objectif nutritionnel (`NutritionGoal`) dit **ce que l'assiette vise**.
Viser un marathon en recomposition corporelle est parfaitement cohérent :
les deux questions se posent séparément (onboarding, étapes 2 et 3) et
s'écrivent séparément — poser l'une n'écrit jamais l'autre, et aucun des
deux ne se déduit de l'autre. Le e2e `auth.e2e-spec.ts` épingle cette
indépendance.

## Les huit objectifs

Perte de gras, Prise de muscle, Recomposition, Hyrox, Marathon, Maintien,
Force, Callisthénie — enum `TrainingGoal` (Prisma, contrat
`trainingGoalSchema`, entité Dart). Les wires ne recoupent JAMAIS ceux de
`NutritionGoal` (`MAINTENANCE` côté entraînement, `MAINTAIN` côté
nutrition) : un wire partagé inviterait à confondre les colonnes — un test
l'interdit.

L'enum est EXTENSIBLE : côté mobile, `TrainingGoal.fromWire` rend `null`
pour toute valeur inconnue — un serveur plus récent n'a pas le droit de
faire planter un ancien client, et jamais un objectif n'est deviné.

## Où il vit, où il se choisit

- **Serveur** : `UserProfile.trainingGoal` (nullable, migration
  `20260917190658_training_goal`), écrit par `PATCH /users/me`, servi dans
  `AuthUser.trainingGoal` — le même chemin que l'identité Carlys et la voix
  du Mentor : une seule source de vérité, choisir écrit PUIS relit.
- **Onboarding** : étape 2 (« Ton entraînement »), juste après l'identité —
  le POURQUOI des séances avant le plan nutrition. Répondu sans compte, il
  attend localement (`OnboardingAnswers`) et part par son endpoint dès
  qu'une session s'ouvre, comme l'identité.
- **Profil** : groupe « Entraînement » → « Mon objectif », feuille à huit
  cartes (image, nom, ce que l'objectif vise, sélection marquée) —
  `training_goal_sheet.dart`, modifiable à tout moment.

## La suite du plan

L'objectif est l'ENTRÉE PREMIÈRE de la génération de programme : les
prochaines tranches ajoutent les autres entrées (expérience,
séances/semaine, durée, matériel), les règles de génération par objectif
(serveur, auditables), puis le calendrier daté. Voir `CARLYS_ROADMAP.md`,
Plan 4.
