import { z } from 'zod';

/** Contrats des endpoints d'état de santé (/health, /health/live, /health/ready). */

export const healthComponentStatusSchema = z.enum(['up', 'down']);

export type HealthComponentStatus = z.infer<typeof healthComponentStatusSchema>;

export const healthComponentSchema = z.object({
  status: healthComponentStatusSchema,
  latencyMs: z.number().optional(),
  error: z.string().optional(),
});

export type HealthComponent = z.infer<typeof healthComponentSchema>;

export const healthReportSchema = z.object({
  status: z.enum(['ok', 'error']),
  timestamp: z.string(),
  uptimeSeconds: z.number(),
  components: z.record(z.string(), healthComponentSchema),
});

export type HealthReport = z.infer<typeof healthReportSchema>;

export const livenessReportSchema = z.object({
  status: z.literal('ok'),
  timestamp: z.string(),
  uptimeSeconds: z.number(),
});

export type LivenessReport = z.infer<typeof livenessReportSchema>;
