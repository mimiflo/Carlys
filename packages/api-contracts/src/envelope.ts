import { z } from 'zod';

/**
 * Enveloppes de réponse communes à toute l'API Carlys.
 *
 * Succès : { data, meta, requestId }
 * Erreur  : { error: { code, message, details, requestId } }
 */

export const apiErrorCodeSchema = z.enum([
  'BAD_REQUEST',
  'VALIDATION_ERROR',
  'UNAUTHORIZED',
  'FORBIDDEN',
  'NOT_FOUND',
  'CONFLICT',
  'PAYLOAD_TOO_LARGE',
  'RATE_LIMITED',
  'INTERNAL_ERROR',
  'SERVICE_UNAVAILABLE',
]);

export type ApiErrorCode = z.infer<typeof apiErrorCodeSchema>;

export const apiErrorDetailSchema = z.object({
  field: z.string().optional(),
  message: z.string(),
});

export type ApiErrorDetail = z.infer<typeof apiErrorDetailSchema>;

export const apiErrorEnvelopeSchema = z.object({
  error: z.object({
    code: apiErrorCodeSchema,
    message: z.string(),
    details: z.array(apiErrorDetailSchema),
    requestId: z.string(),
  }),
});

export type ApiErrorEnvelope = z.infer<typeof apiErrorEnvelopeSchema>;

export interface ApiSuccessEnvelope<TData, TMeta extends object = Record<string, never>> {
  data: TData;
  meta: TMeta;
  requestId: string;
}

/** Métadonnées de pagination par curseur. */
export const cursorPaginationMetaSchema = z.object({
  nextCursor: z.string().nullable(),
  hasMore: z.boolean(),
});

export type CursorPaginationMeta = z.infer<typeof cursorPaginationMetaSchema>;
