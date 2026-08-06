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

const STATUS_TO_CODE: Readonly<Record<number, ApiErrorCode>> = {
  [HttpStatus.BAD_REQUEST]: 'BAD_REQUEST',
  [HttpStatus.UNAUTHORIZED]: 'UNAUTHORIZED',
  [HttpStatus.FORBIDDEN]: 'FORBIDDEN',
  [HttpStatus.NOT_FOUND]: 'NOT_FOUND',
  [HttpStatus.CONFLICT]: 'CONFLICT',
  [HttpStatus.PAYLOAD_TOO_LARGE]: 'PAYLOAD_TOO_LARGE',
  [HttpStatus.TOO_MANY_REQUESTS]: 'RATE_LIMITED',
  [HttpStatus.SERVICE_UNAVAILABLE]: 'SERVICE_UNAVAILABLE',
};

/**
 * Convertit toute exception en enveloppe d'erreur normalisée
 * `{ error: { code, message, details, requestId } }` sans fuiter de détails
 * internes pour les erreurs 5xx.
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
      const payload = exception.getResponse();

      if (typeof payload === 'string') {
        message = payload;
      } else if (payload !== null && typeof payload === 'object') {
        const body = payload as { message?: string | string[] };
        if (Array.isArray(body.message)) {
          code = status === Number(HttpStatus.BAD_REQUEST) ? 'VALIDATION_ERROR' : code;
          message = 'Certaines données sont invalides.';
          details = body.message.map((entry) => ({ message: entry }));
        } else if (typeof body.message === 'string') {
          message = body.message;
        }
      }

      if (status >= 500) {
        message = 'Une erreur interne est survenue.';
        details = [];
        this.logger.error({ err: exception, requestId, status }, 'Exception HTTP 5xx');
      }
    } else {
      this.logger.error({ err: exception, requestId }, 'Exception non gérée');
    }

    const body: ApiErrorEnvelope = {
      error: { code, message, details, requestId },
    };
    response.status(status).json(body);
  }
}
