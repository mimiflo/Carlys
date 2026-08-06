import { type ApiSuccessEnvelope } from '@carlys/api-contracts';
import { API_GLOBAL_PREFIX } from '@carlys/shared-config';
import {
  type CallHandler,
  type ExecutionContext,
  Injectable,
  type NestInterceptor,
  StreamableFile,
} from '@nestjs/common';
import { map, type Observable } from 'rxjs';
import { requestIdOf, type RequestWithId } from '../types/request-with-id';

type EnvelopedResponse = ApiSuccessEnvelope<unknown, Record<string, unknown>>;

function isAlreadyEnveloped(payload: unknown): payload is EnvelopedResponse {
  return (
    payload !== null &&
    typeof payload === 'object' &&
    'data' in payload &&
    'meta' in payload &&
    'requestId' in payload
  );
}

/**
 * Enveloppe toutes les réponses des routes métier (/api/…) dans le format
 * `{ data, meta, requestId }`. Les endpoints techniques (/health, /metrics)
 * et les flux binaires ne sont pas enveloppés.
 */
@Injectable()
export class ResponseEnvelopeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<RequestWithId>();
    const url = request.originalUrl ?? request.url;

    if (!url.startsWith(`/${API_GLOBAL_PREFIX}/`)) {
      return next.handle();
    }

    const requestId = requestIdOf(request);

    return next.handle().pipe(
      map((payload: unknown) => {
        if (payload instanceof StreamableFile || isAlreadyEnveloped(payload)) {
          return payload;
        }
        const envelope: EnvelopedResponse = {
          data: payload ?? null,
          meta: {},
          requestId,
        };
        return envelope;
      }),
    );
  }
}
