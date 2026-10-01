import {
  TRAINING_SESSION_MINUTES_MAX,
  TRAINING_SESSION_MINUTES_MIN,
  TRAINING_WEEKLY_SESSIONS_MAX,
  TRAINING_WEEKLY_SESSIONS_MIN,
} from '@carlys/api-contracts';
import { TrainingGoal } from '@prisma/client';
import { type CoachToolDefinition } from '../domain/coach-model.port';

/**
 * Ce que le coach VOIT de ses outils : noms, descriptions, schémas. Leur
 * exécution vit dans `coach.tools.ts` ; les deux propositions
 * (`propose_session`, `propose_program`) ne sont pas exécutées, elles sont
 * retenues et validées par le serveur.
 *
 * Chaque description dit QUAND appeler l'outil, pas seulement ce qu'il fait :
 * c'est ce qui pèse le plus sur la justesse du déclenchement.
 */

export const PROPOSE_SESSION_TOOL = 'propose_session';
export const PROPOSE_PROGRAM_TOOL = 'propose_program';

export const COACH_TOOLS: CoachToolDefinition[] = [
  {
    name: 'search_exercises',
    description:
      'Cherche des exercices dans le catalogue. Appelle-le dès que tu dois nommer ' +
      'un exercice ou obtenir son identifiant — tu ne peux en proposer aucun sans ' +
      'être passé par ici.',
    inputSchema: {
      type: 'object',
      properties: {
        search: {
          type: 'string',
          description:
            'Mots du NOM de l’exercice (« développé », « squat »). Pour un muscle ' +
            'ou un matériel, utilise plutôt les deux champs suivants.',
        },
        muscleGroupSlug: {
          type: 'string',
          description:
            'pectoraux, dos, epaules, biceps, triceps, avant-bras, abdominaux, ' +
            'lombaires, quadriceps, ischio-jambiers, fessiers ou mollets.',
        },
        equipmentSlug: {
          type: 'string',
          description: 'Ex. barre, halteres, poids-du-corps, machine, poulie, kettlebell.',
        },
      },
    },
  },
  {
    name: 'list_workout_templates',
    description:
      'Liste les modèles de séance de l’utilisateur. Appelle-le AVANT toute ' +
      'adaptation de séance : partir de ce qu’il a prévu vaut mieux que composer ' +
      'de zéro.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_workout_template',
    description:
      'Détaille un modèle : exercices, séries prévues, charges cibles, repos. ' +
      'Appelle-le quand tu adaptes une séance à partir d’un modèle.',
    inputSchema: {
      type: 'object',
      properties: { templateId: { type: 'string' } },
      required: ['templateId'],
    },
  },
  {
    name: 'get_recent_sessions',
    description:
      'Les dernières séances terminées. Appelle-le pour savoir ce qui a été fait ' +
      'récemment, à quelle charge, et à quelle fréquence.',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'integer', description: 'Nombre de séances (défaut 10).' },
      },
    },
  },
  {
    name: 'get_personal_records',
    description:
      'Les records de l’utilisateur, recalculés à la clôture de chaque séance. ' +
      'Appelle-le pour situer une performance ou proposer une charge.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_progress_overview',
    description:
      'Volume, assiduité et tendances sur une période. Appelle-le quand la ' +
      'question porte sur la progression d’ensemble plutôt que sur une séance.',
    inputSchema: {
      type: 'object',
      properties: {
        period: { type: 'string', enum: ['week', 'month', 'year'] },
      },
    },
  },
  {
    name: 'get_body_weight_trend',
    description:
      'Les dernières pesées, de la plus ancienne à la plus récente. Appelle-le ' +
      'quand la question touche au poids ou à une évolution corporelle.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_nutrition_targets',
    description:
      'Les cibles caloriques et de macros calculées par l’application. ATTENTION : ' +
      'ce sont des OBJECTIFS, pas ce qui a été mangé. Pour les apports réels, ' +
      'appelle get_recent_meals : tu ne connais que ce qui y est noté.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_recent_meals',
    description:
      'Le journal alimentaire : les repas notés par l’utilisateur sur les derniers ' +
      'jours (nom, moment de la journée, kcal, macros, aliments et grammes quand ' +
      'le repas est composé, instant UTC). moment vaut BREAKFAST, LUNCH, DINNER ' +
      'ou SNACK, ou null quand il n’a pas été noté. Appelle-le quand la question ' +
      'touche à ce qu’il mange réellement. Un journal vide ne prouve pas qu’il ' +
      'n’a rien mangé : seulement qu’il n’a rien noté.',
    inputSchema: {
      type: 'object',
      properties: {
        days: {
          type: 'integer',
          description: 'Nombre de jours en arrière (défaut 1, maximum 7).',
        },
      },
    },
  },
  {
    name: 'get_training_profile',
    description:
      'Le profil d’entraînement : objectif, niveau, séances visées par semaine, durée ' +
      'visée d’une séance, matériel, et le programme actif s’il y en a un. Appelle-le ' +
      'AVANT de proposer un programme, pour partir de ce qui est déjà en place.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: PROPOSE_PROGRAM_TOOL,
    description:
      'Propose un PROGRAMME sur plusieurs semaines. N’écrit RIEN et ne compose pas les ' +
      'séances : tu choisis les réglages, le générateur de Carlys construit le programme ' +
      'quand l’utilisateur l’accepte. Appelle-le quand il demande un programme, un plan, ' +
      'ou de changer d’objectif ou de rythme. Ne décris pas les séances dans ta réponse : ' +
      'dis en une ou deux phrases pourquoi ces réglages.',
    inputSchema: {
      type: 'object',
      properties: {
        goal: {
          type: 'string',
          enum: Object.values(TrainingGoal),
          description: 'Objectif du programme.',
        },
        weeklySessions: {
          type: 'integer',
          description: `Séances par semaine (${TRAINING_WEEKLY_SESSIONS_MIN} à ${TRAINING_WEEKLY_SESSIONS_MAX}).`,
        },
        sessionMinutes: {
          type: 'integer',
          description: `Durée d’une séance en minutes (${TRAINING_SESSION_MINUTES_MIN} à ${TRAINING_SESSION_MINUTES_MAX}).`,
        },
      },
      required: ['goal', 'weeklySessions', 'sessionMinutes'],
    },
  },
  {
    name: PROPOSE_SESSION_TOOL,
    description:
      'Propose une séance adaptée. N’écrit RIEN : produit un document que ' +
      'l’utilisateur acceptera ou non. Chaque exerciseId doit venir d’un outil de ' +
      'lecture ; un identifiant inventé fait rejeter toute la proposition. Les ' +
      'positions commencent à 0 et se suivent sans trou.',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Nom court de la séance.' },
        estimatedMinutes: { type: 'integer' },
        items: {
          type: 'array',
          description: 'Une entrée PAR SÉRIE, pas par exercice.',
          items: {
            type: 'object',
            properties: {
              exercisePosition: { type: 'integer' },
              exerciseId: { type: 'string' },
              setPosition: { type: 'integer' },
              kind: { type: 'string', enum: ['WARMUP', 'NORMAL', 'DROP'] },
              targetReps: { type: 'integer' },
              targetWeightKg: { type: 'number' },
              restSeconds: { type: 'integer' },
            },
            required: ['exercisePosition', 'exerciseId', 'setPosition'],
          },
        },
      },
      required: ['name', 'estimatedMinutes', 'items'],
    },
  },
];
