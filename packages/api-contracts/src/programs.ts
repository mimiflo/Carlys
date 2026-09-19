import { z } from 'zod';

/**
 * Programmes multi-semaines (/api/v1/programs).
 *
 * Un programme dit **quand** s'entraîner ; le modèle de séance dit **quoi**
 * faire. Le programme ne duplique donc aucun exercice : chaque jour renvoie à
 * un modèle existant, ou n'annonce qu'un intitulé (repos, activité libre).
 *
 * Mêmes règles d'écriture que les modèles de séance (Étape 4) : identifiants
 * fournis par l'appareil — donc création hors ligne et rejeu sans doublon —
 * et **unique écriture** `PUT`, qui décrit l'état complet.
 */

export const PROGRAM_MAX_WEEKS = 52;
export const PROGRAM_MAX_DAYS = 7 * PROGRAM_MAX_WEEKS;

/** Nombre de programmes gardés sans abonnement (`unlimited_programs`). */
export const PROGRAM_FREE_LIMIT = 2;

export const programDaySchema = z.object({
  id: z.string(),
  weekNumber: z.number().int(),
  /** 1 = lundi … 7 = dimanche. */
  dayOfWeek: z.number().int(),
  templateId: z.string().nullable(),
  label: z.string(),
  isRest: z.boolean(),
});
export type ProgramDay = z.infer<typeof programDaySchema>;

/**
 * Un jour civil `YYYY-MM-DD`, jamais un instant ISO 8601.
 *
 * `Program.startsOn` dit QUEL JOUR le plan commence, pas à quelle seconde.
 * Servi en instant, il se ferait convertir en heure locale par le client —
 * comme tout le reste, à raison — et reculerait d'un jour à l'ouest de
 * Greenwich. Une chaîne ne se convertit pas par accident.
 */
export const dayKeySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const programSummarySchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  weeksCount: z.number().int(),
  isActive: z.boolean(),
  /**
   * Premier jour du plan, ou `null` pour un programme sans calendrier — il
   * reste alors la grille (semaine N, jour J) qu'il a toujours été.
   */
  startsOn: dayKeySchema.nullable(),
  /** Jours renseignés, repos compris — ce qui donne l'avancement du plan. */
  daysCount: z.number().int(),
  updatedAt: z.string(),
});
export type ProgramSummary = z.infer<typeof programSummarySchema>;

export const programDetailSchema = programSummarySchema.extend({
  days: z.array(programDaySchema),
});
export type ProgramDetail = z.infer<typeof programDetailSchema>;

/** Jour envoyé par le client. `label` est déduit du modèle s'il est absent. */
export const saveProgramDaySchema = z.object({
  id: z.string().uuid(),
  weekNumber: z.number().int().min(1).max(PROGRAM_MAX_WEEKS),
  dayOfWeek: z.number().int().min(1).max(7),
  templateId: z.string().uuid().nullable().optional(),
  label: z.string().trim().min(1).max(120).optional(),
  isRest: z.boolean().optional(),
});
export type SaveProgramDay = z.infer<typeof saveProgramDaySchema>;

/**
 * Corps du `PUT /programs/:id` — l'état COMPLET du programme.
 *
 * Le serveur y fait converger la base en une transaction : rejouer le même
 * corps redonne exactement le même état, sans journal d'idempotence.
 */
export const saveProgramRequestSchema = z.object({
  name: z.string().trim().min(1).max(120),
  description: z.string().trim().max(2000).nullable().optional(),
  weeksCount: z.number().int().min(1).max(PROGRAM_MAX_WEEKS),
  isActive: z.boolean().optional(),
  /**
   * Premier jour du plan. ABSENT vaut `null` comme le reste du corps — c'est
   * un état complet, pas un fragment : un client qui garde la date la renvoie.
   *
   * Aucune borne haute, contrairement aux dates d'ÉVÉNEMENT (`startedAt`,
   * `measuredAt`, `eatenAt`) qui refusent le futur : commencer lundi
   * prochain est le cas normal, pas une horloge déréglée.
   */
  startsOn: dayKeySchema.nullable().optional(),
  days: z.array(saveProgramDaySchema).max(PROGRAM_MAX_DAYS),
});
export type SaveProgramRequest = z.infer<typeof saveProgramRequestSchema>;

// ── Calendrier daté (Plan 4, tranche 4) ─────────────────────────────────────

/**
 * L'état d'une case, DÉDUIT à chaque lecture — rien de tout cela n'est
 * stocké.
 *
 * `before` est la nuance qui évite le mur rouge : commencer un mercredi
 * laisse lundi et mardi de la semaine 1 avant le départ, et ces jours-là
 * n'ont jamais été promis.
 */
export const programDayStatusSchema = z.enum([
  /** Aucune case n'occupe ce jour : rien n'était prévu, rien n'est reproché. */
  'free',
  /** Repos EXPLICITEMENT planifié — ce n'est pas la même chose que `free`. */
  'rest',
  'done',
  'missed',
  'before',
  'upcoming',
]);
export type ProgramDayStatus = z.infer<typeof programDayStatusSchema>;

export const programCalendarDaySchema = z.object({
  /** `null` quand aucune case n'occupe ce jour — le calendrier montre les sept. */
  id: z.string().nullable(),
  weekNumber: z.number().int(),
  dayOfWeek: z.number().int(),
  templateId: z.string().nullable(),
  label: z.string().nullable(),
  isRest: z.boolean(),
  /** Le jour civil de cette case, `YYYY-MM-DD`. */
  date: dayKeySchema,
  status: programDayStatusSchema,
  /** La séance TERMINÉE qui honore cette case, s'il y en a une. */
  sessionId: z.string().nullable(),
});
export type ProgramCalendarDay = z.infer<typeof programCalendarDaySchema>;

/**
 * Une semaine datée du programme — ce que `GET /programs/:id/calendar` rend.
 *
 * Toujours SEPT jours, y compris ceux qu'aucune case ne remplit : un
 * calendrier qui saute les jours vides n'est plus un calendrier.
 */
export const programCalendarWeekSchema = z.object({
  programId: z.string(),
  name: z.string(),
  weeksCount: z.number().int(),
  startsOn: dayKeySchema,
  /** Semaine servie, et celle qui contient aujourd'hui (`null` hors plan). */
  weekNumber: z.number().int(),
  currentWeek: z.number().int().nullable(),
  /** Aujourd'hui dans le fuseau de la personne — l'écran n'en décide pas. */
  today: dayKeySchema,
  days: z.array(programCalendarDaySchema),
});
export type ProgramCalendarWeek = z.infer<typeof programCalendarWeekSchema>;

// ── Génération de programme (Plan 4, tranche 3) ─────────────────────────────

/**
 * Un ASSOUPLISSEMENT consenti par le générateur, nommé et chiffré.
 *
 * C'est ce qui rend la génération auditable : le programme ne dit pas
 * seulement ce qu'il prescrit, il dit où il a dû céder et de combien. Un
 * générateur qui livre en silence un dos à quatre séries quand la règle en
 * demande douze ment par omission.
 *
 * `code` nomme la règle (`R1_VOLUME_AU_MINIMUM`, `R6_GROUPE_SOUS_LE_MINIMUM`…),
 * `subject` le groupe musculaire ou le jour concerné quand il y en a un,
 * `expected` et `actual` les deux nombres qui font la différence.
 */
export const generationRelaxationSchema = z.object({
  code: z.string(),
  subject: z.string().nullable(),
  expected: z.number().nullable(),
  actual: z.number().nullable(),
  message: z.string(),
});
export type GenerationRelaxation = z.infer<typeof generationRelaxationSchema>;

/** Séries hebdomadaires réellement allouées à un groupe, et la cible visée. */
export const generationVolumeSchema = z.object({
  muscleGroup: z.string(),
  weeklySets: z.number().int(),
  targetMin: z.number().int(),
  targetMax: z.number().int(),
});
export type GenerationVolume = z.infer<typeof generationVolumeSchema>;

/**
 * Ce que le générateur a produit, et ce qu'il n'a pas pu produire.
 *
 * `templatedDays` / `freeLabelDays` comptent les jours actifs selon qu'ils
 * portent un modèle de séance ou seulement un intitulé. L'écart n'est pas un
 * détail pour MARATHON et HYROX : le catalogue ne contient aucun exercice de
 * course, de rameur ni de traîneau, donc ces séances-là sont PLANIFIÉES mais
 * pas détaillées, et elles ne produiront ni séance, ni record, ni courbe de
 * progression dans l'application. L'utilisateur doit l'apprendre ici, pas de
 * sa propre déception au bout de trois semaines.
 */
export const generationReportSchema = z.object({
  status: z.enum(['satisfied', 'relaxed']),
  rulesVersion: z.number().int(),
  goal: z.string(),
  experience: z.string(),
  /** Séances par semaine réellement retenues, après normalisation. */
  sessionsPerWeek: z.number().int(),
  split: z.array(z.string()),
  templatedDays: z.number().int(),
  freeLabelDays: z.number().int(),
  restDays: z.number().int(),
  templatesCreated: z.number().int(),
  weeklyVolume: z.array(generationVolumeSchema),
  /** Groupes du découpage qu'aucun exercice jouable ne couvre en principal. */
  uncoveredGroups: z.array(z.string()),
  relaxations: z.array(generationRelaxationSchema),
  /** Phrases d'explication destinées à l'écran, déjà rédigées côté serveur. */
  notes: z.array(z.string()),
});
export type GenerationReport = z.infer<typeof generationReportSchema>;

/** Réponse de `PUT /programs/:id/generate`. */
export const generatedProgramSchema = z.object({
  program: programDetailSchema,
  report: generationReportSchema,
});
export type GeneratedProgram = z.infer<typeof generatedProgramSchema>;
