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

export const programSummarySchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  weeksCount: z.number().int(),
  isActive: z.boolean(),
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
  days: z.array(saveProgramDaySchema).max(PROGRAM_MAX_DAYS),
});
export type SaveProgramRequest = z.infer<typeof saveProgramRequestSchema>;
