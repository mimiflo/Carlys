import {
  type ApiErrorCode,
  type ApiErrorDetail,
  type ApiErrorEnvelope,
} from '@carlys/api-contracts';
import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { type Response } from 'express';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { requestIdOf, type RequestWithId } from '../types/request-with-id';
import { IdentifierConflictException } from './identifier-conflict.exception';
import { UserFacingUnavailableException } from './user-facing-unavailable.exception';

const STATUS_TO_CODE: Readonly<Record<number, ApiErrorCode>> = {
  [HttpStatus.BAD_REQUEST]: 'BAD_REQUEST',
  [HttpStatus.UNAUTHORIZED]: 'UNAUTHORIZED',
  [HttpStatus.FORBIDDEN]: 'FORBIDDEN',
  [HttpStatus.NOT_FOUND]: 'NOT_FOUND',
  [HttpStatus.CONFLICT]: 'CONFLICT',
  [HttpStatus.PAYLOAD_TOO_LARGE]: 'PAYLOAD_TOO_LARGE',
  [HttpStatus.UNSUPPORTED_MEDIA_TYPE]: 'UNSUPPORTED_MEDIA_TYPE',
  [HttpStatus.TOO_MANY_REQUESTS]: 'RATE_LIMITED',
  [HttpStatus.SERVICE_UNAVAILABLE]: 'SERVICE_UNAVAILABLE',
};

const DEFAULT_VALIDATION_MESSAGE = 'Certaines données sont invalides.';

/**
 * Messages des erreurs levées AVANT le routage par les intergiciels Express
 * (body-parser et ses cousins, qui suivent la convention `http-errors`). Leur
 * propre message (« request entity too large ») est anglais et technique ;
 * on n'en garde que le statut.
 */
const PRE_ROUTING_MESSAGES: Readonly<Record<number, string>> = {
  [HttpStatus.PAYLOAD_TOO_LARGE]: 'Le corps de la requête est trop volumineux.',
  [HttpStatus.UNSUPPORTED_MEDIA_TYPE]: 'Ce type de contenu n’est pas pris en charge.',
};
const PRE_ROUTING_DEFAULT_MESSAGE = 'La requête est mal formée.';

interface ClientHttpError {
  status: number;
  type?: unknown;
}

/**
 * Une erreur CLIENT au sens de `http-errors` : un statut 4xx et
 * `expose === true` (la bibliothèque dit elle-même que le message peut être
 * montré). C'est ce que lèvent les parseurs de corps : corps trop lourd
 * (413, y compris un gzip qui gonfle au-delà de la limite après
 * décompression), encodage inconnu (415), gzip corrompu ou jeu de caractères
 * invalide (400). Ce n'est ni une HttpException ni une SyntaxError — les
 * deux seules formes que Nest convertit —, et le filtre en faisait un 500.
 */
function asClientHttpError(exception: unknown): ClientHttpError | null {
  if (typeof exception !== 'object' || exception === null) {
    return null;
  }
  const candidate = exception as { status?: unknown; statusCode?: unknown; expose?: unknown };
  const status = typeof candidate.status === 'number' ? candidate.status : candidate.statusCode;
  if (typeof status !== 'number' || status < 400 || status > 499 || candidate.expose !== true) {
    return null;
  }
  return { status, type: (exception as { type?: unknown }).type };
}

/** Le corps porte-t-il des détails déjà structurés `{ field?, message }` ? */
function isDetailList(value: unknown): value is ApiErrorDetail[] {
  return (
    Array.isArray(value) &&
    value.every(
      (entry) =>
        typeof entry === 'object' &&
        entry !== null &&
        typeof (entry as { message?: unknown }).message === 'string',
    )
  );
}

/**
 * Convertit toute exception en enveloppe d'erreur normalisée
 * `{ error: { code, message, details, requestId } }` sans fuiter de détails
 * internes pour les erreurs 5xx — sauf le message d'un
 * [UserFacingUnavailableException], écrit pour la personne.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  constructor(
    @InjectPinoLogger(AllExceptionsFilter.name)
    private readonly logger: PinoLogger,
  ) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<RequestWithId>();
    const requestId = requestIdOf(request);

    let status: number = HttpStatus.INTERNAL_SERVER_ERROR;
    let code: ApiErrorCode = 'INTERNAL_ERROR';
    let message = 'Une erreur interne est survenue.';
    let details: ApiErrorDetail[] = [];

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      code = STATUS_TO_CODE[status] ?? (status >= 500 ? 'INTERNAL_ERROR' : 'BAD_REQUEST');
      if (exception instanceof IdentifierConflictException) code = 'IDENTIFIER_CONFLICT';
      const payload = exception.getResponse();

      if (typeof payload === 'string') {
        message = payload;
      } else if (payload !== null && typeof payload === 'object') {
        const body = payload as { message?: string | string[]; details?: unknown };
        if (isDetailList(body.details)) {
          // Erreur de validation STRUCTURÉE (voir
          // `validation-exception.factory.ts`) : chaque message porte son
          // champ, et le client peut les placer sous les bons libellés.
          code = status === Number(HttpStatus.BAD_REQUEST) ? 'VALIDATION_ERROR' : code;
          message = typeof body.message === 'string' ? body.message : DEFAULT_VALIDATION_MESSAGE;
          details = body.details;
        } else if (Array.isArray(body.message)) {
          // Repli : un tableau de phrases sans champ. Ce que rendait la
          // fabrique par défaut de NestJS ; conservé pour toute exception
          // construite à la main sous cette forme.
          code = status === Number(HttpStatus.BAD_REQUEST) ? 'VALIDATION_ERROR' : code;
          message = DEFAULT_VALIDATION_MESSAGE;
          details = body.message.map((entry) => ({ message: entry }));
        } else if (typeof body.message === 'string') {
          message = body.message;
        }
      }

      if (status >= 500) {
        if (exception instanceof UserFacingUnavailableException) {
          code = exception.code;
        } else {
          message = 'Une erreur interne est survenue.';
        }
        details = [];
        this.logger.error({ err: exception, requestId, status }, 'Exception HTTP 5xx');
      }
    } else {
      const clientError = asClientHttpError(exception);
      if (clientError === null) {
        this.logger.error({ err: exception, requestId }, 'Exception non gérée');
      } else {
        // Refus d'un intergiciel AVANT le routage : c'est le client qui s'est
        // trompé (ou qui essaie). Un 500 « Exception non gérée », stack
        // comprise, gonflait à volonté le journal d'erreurs et la métrique
        // 5xx — et ces requêtes ne passent même pas par le ThrottlerGuard.
        status = clientError.status;
        code = STATUS_TO_CODE[status] ?? 'BAD_REQUEST';
        message = PRE_ROUTING_MESSAGES[status] ?? PRE_ROUTING_DEFAULT_MESSAGE;
        this.logger.warn(
          { requestId, status, type: clientError.type },
          'Requête refusée avant le routage',
        );
      }
    }

    const body: ApiErrorEnvelope = {
      error: { code, message, details, requestId },
    };
    if (response.headersSent) {
      // Réponse déjà commencée. EN FLUX (SSE) : l'erreur devient son dernier
      // évènement, avec la même enveloppe. Toute autre : on coupe, plutôt que
      // de coller une enveloppe au bout d'un corps d'un autre format.
      const sse = String(response.getHeader('Content-Type')).startsWith('text/event-stream');
      if (response.writableEnded || response.destroyed) return;
      if (sse) response.end(`event: error\ndata: ${JSON.stringify(body)}\n\n`);
      else response.destroy();
      return;
    }
    response.status(status).json(body);
  }
}
