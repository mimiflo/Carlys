import { MEDIA_TRANSPORT_HARD_CAP_BYTES } from '@carlys/api-contracts';
import {
  BadRequestException,
  type CallHandler,
  type ExecutionContext,
  HttpException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { lastValueFrom, throwError } from 'rxjs';
import { singleFileLimits, UploadErrorsInFrench } from './single-file-upload';

/** Ce que l'intercepteur rend quand la suite de la chaîne lève `error`. */
async function translated(error: unknown): Promise<unknown> {
  const next: CallHandler = { handle: () => throwError(() => error) };
  try {
    await lastValueFrom(
      new UploadErrorsInFrench('Photo trop lourde.').intercept({} as ExecutionContext, next),
    );
  } catch (caught) {
    return caught;
  }
  throw new Error('L’erreur devait traverser l’intercepteur.');
}

function messageOf(error: unknown): unknown {
  return error instanceof HttpException
    ? (error.getResponse() as { message?: unknown }).message
    : undefined;
}

describe('singleFileLimits', () => {
  it('un fichier, la protection d’index de tableau ARMÉE, coupé à la taille demandée', () => {
    expect(singleFileLimits(5_000)).toEqual({ files: 1, fileSize: 5_000, fieldArrayIndexLimit: 0 });
    expect(singleFileLimits(5_000, 0)).toMatchObject({ fields: 0 });
  });

  it('jamais au-delà du plafond de transport commun', () => {
    expect(singleFileLimits(MEDIA_TRANSPORT_HARD_CAP_BYTES * 2).fileSize).toBe(
      MEDIA_TRANSPORT_HARD_CAP_BYTES,
    );
  });
});

describe('UploadErrorsInFrench', () => {
  it('« File too large » de multer devient le 413 de la route, en français', async () => {
    const error = await translated(new PayloadTooLargeException('File too large'));
    expect(error).toBeInstanceOf(PayloadTooLargeException);
    expect(messageOf(error)).toBe('Photo trop lourde.');
  });

  it('les refus de forme du multipart deviennent des 400 en français', async () => {
    expect(messageOf(await translated(new BadRequestException('Too many files')))).toBe(
      'Un seul fichier par envoi.',
    );
    expect(messageOf(await translated(new BadRequestException('Unexpected field - photo')))).toBe(
      'Fichier reçu dans un champ inattendu : envoie-le dans « file ».',
    );
    expect(messageOf(await translated(new BadRequestException('Too many fields')))).toBe(
      'Trop de champs dans l’envoi.',
    );
  });

  it('l’erreur que Nest ne traduit pas (LIMIT_FIELD_ARRAY_INDEX) devient un 400, plus un 500', async () => {
    const multer = Object.assign(new Error('Field name array index too large'), {
      name: 'MulterError',
      code: 'LIMIT_FIELD_ARRAY_INDEX',
    });
    const error = await translated(multer);
    expect(error).toBeInstanceOf(BadRequestException);
    expect(messageOf(error)).toBe('Nom de champ refusé.');
  });

  it('une erreur du SERVICE, déjà en français, traverse inchangée', async () => {
    const service = new UnsupportedMediaTypeException('Seul le JPEG est accepté.');
    expect(await translated(service)).toBe(service);
    const serviceTooLarge = new PayloadTooLargeException('Photo trop lourde : 5 Mo au plus.');
    expect(await translated(serviceTooLarge)).toBe(serviceTooLarge);
    const validation = new BadRequestException('Aucune photo reçue.');
    expect(await translated(validation)).toBe(validation);
  });
});
