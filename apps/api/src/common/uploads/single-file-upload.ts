import { MEDIA_TRANSPORT_HARD_CAP_BYTES } from '@carlys/api-contracts';
import {
  BadRequestException,
  type CallHandler,
  type ExecutionContext,
  HttpException,
  HttpStatus,
  type NestInterceptor,
  PayloadTooLargeException,
} from '@nestjs/common';
import type { MulterOptions } from '@nestjs/platform-express/multer/interfaces/multer-options.interface';
import { catchError, type Observable, throwError } from 'rxjs';

/**
 * Garde-fous multer d'une route qui reçoit UN fichier.
 *
 * `fieldArrayIndexLimit: 0` ARME le correctif de GHSA-535w-7cp7-47q4. multer
 * 2.3.0 le livre ÉTEINT (défaut `Infinity`) : l'audit de sécurité passe au
 * vert sans que la protection existe. Sans elle, un nom de champ
 * `a[999999999]` fait allouer un tableau creux de cette taille pendant
 * l'analyse du multipart. Zéro, parce qu'aucune route de dépôt n'utilise la
 * syntaxe tableau.
 *
 * Le type est ÉLARGI localement : @types/multer s'arrête à 2.2.0, qui ignore
 * cette limite — les types sont en retard sur l'exécutable (résolu : multer
 * 2.3.0, vérifié). L'intersection reste assignable au `limits` de Nest sans
 * cast ni `any`, et cette déclaration disparaîtra quand @types/multer ≥ 2.3
 * existera.
 */
export type SingleFileLimits = NonNullable<MulterOptions['limits']> & {
  fieldArrayIndexLimit: number;
};

/**
 * Un fichier, coupé PENDANT la réception dès `maxBytes` (jamais au-delà du
 * plafond de transport commun) : un envoi démesuré n'est jamais gardé
 * entier en mémoire. `fields` borne les champs texte ; une route qui n'en
 * attend aucun passe 0, et tout champ en trop est refusé au lieu d'être
 * ignoré.
 */
export function singleFileLimits(maxBytes: number, fields?: number): SingleFileLimits {
  return {
    files: 1,
    fileSize: Math.min(maxBytes, MEDIA_TRANSPORT_HARD_CAP_BYTES),
    fieldArrayIndexLimit: 0,
    ...(fields === undefined ? {} : { fields }),
  };
}

/**
 * Les refus de multer, en français. Nest les relaie avec le texte anglais de
 * multer (« File too large »), que l'application afficherait tel quel.
 */
const MULTER_MESSAGES: ReadonlyArray<readonly [string, string]> = [
  ['Too many files', 'Un seul fichier par envoi.'],
  ['Unexpected field', 'Fichier reçu dans un champ inattendu : envoie-le dans « file ».'],
  ['Too many fields', 'Trop de champs dans l’envoi.'],
  ['Too many parts', 'Envoi découpé en trop de parties.'],
  ['Field name too long', 'Nom de champ trop long.'],
  ['Field value too long', 'Valeur de champ trop longue.'],
  ['Field name missing', 'Champ sans nom.'],
  ['Field name array index too large', 'Nom de champ refusé.'],
  ['Multipart', 'Envoi multipart illisible ou interrompu.'],
];

function frenchFor(message: string): string | undefined {
  return MULTER_MESSAGES.find(([english]) => message.startsWith(english))?.[1];
}

function messageOf(error: HttpException): string {
  const body = error.getResponse();
  if (typeof body === 'string') {
    return body;
  }
  const message = (body as { message?: unknown }).message;
  return typeof message === 'string' ? message : '';
}

/**
 * Traduit les refus du transport multipart — et eux seuls : une erreur
 * levée par le service (déjà en français) traverse inchangée.
 *
 * Elle rattrape aussi l'erreur que Nest ne sait pas traduire : multer 2.3
 * ajoute `LIMIT_FIELD_ARRAY_INDEX`, absente de la table de Nest, qui
 * remontait telle quelle et devenait un 500.
 *
 * S'emploie AVANT l'intercepteur de fichier, dont elle enveloppe l'exécution :
 * `@UseInterceptors(new UploadErrorsInFrench('…'), FileInterceptor(…))`.
 */
export class UploadErrorsInFrench implements NestInterceptor {
  constructor(private readonly tooLargeMessage: string) {}

  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next
      .handle()
      .pipe(catchError((error: unknown) => throwError(() => this.translate(error))));
  }

  private translate(error: unknown): unknown {
    if (error instanceof HttpException) {
      const message = messageOf(error);
      if (error.getStatus() === Number(HttpStatus.PAYLOAD_TOO_LARGE)) {
        return message === 'File too large'
          ? new PayloadTooLargeException(this.tooLargeMessage)
          : error;
      }
      const french =
        error.getStatus() === Number(HttpStatus.BAD_REQUEST) ? frenchFor(message) : undefined;
      return french === undefined ? error : new BadRequestException(french);
    }
    if (error instanceof Error && error.name === 'MulterError') {
      return (error as Error & { code?: string }).code === 'LIMIT_FILE_SIZE'
        ? new PayloadTooLargeException(this.tooLargeMessage)
        : new BadRequestException(frenchFor(error.message) ?? 'Envoi multipart refusé.');
    }
    return error;
  }
}
