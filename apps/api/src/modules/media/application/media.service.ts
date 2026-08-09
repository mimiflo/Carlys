import {
  MEDIA_ALLOWED_MIME_TYPES,
  type MediaAsset as MediaAssetContract,
  type MediaKind,
} from '@carlys/api-contracts';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { type MediaAsset } from '@prisma/client';
import { createHash } from 'node:crypto';
import { AppConfigService } from '../../../config/app-config.service';
import { StorageService } from '../../../infrastructure/storage/storage.service';
import { AuditService } from '../../audit/audit.service';
import { ExercisesService } from '../../exercises/application/exercises.service';
import { MediaRepository } from '../infrastructure/media.repository';
import { readImageSize } from './image-size';

/** Qui agit — repris tel quel dans l'audit, jamais deviné côté service. */
export interface MediaActor {
  adminUserId: string;
  requestId?: string;
  ipAddress?: string;
}

/** Extension déduite du type MIME — jamais du nom déposé. */
const EXTENSIONS: Record<string, string> = {
  'image/webp': 'webp',
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/avif': 'avif',
  'model/gltf-binary': 'glb',
  'model/gltf+json': 'gltf',
  'video/mp4': 'mp4',
  'video/webm': 'webm',
};

/**
 * Dépôt et cycle de vie des médias.
 *
 * L'ordre compte : **l'objet part au stockage AVANT la ligne en base**. Une
 * ligne sans objet donnerait une URL morte servie à toutes les applications ;
 * un objet sans ligne n'est qu'un fichier orphelin, invisible et rattrapable.
 */
@Injectable()
export class MediaService {
  constructor(
    private readonly repository: MediaRepository,
    private readonly storage: StorageService,
    private readonly config: AppConfigService,
    private readonly exercises: ExercisesService,
    private readonly audit: AuditService,
  ) {}

  async upload(input: {
    id: string;
    kind: MediaKind;
    mimeType: string;
    originalName: string;
    content: Buffer;
    actor: MediaActor;
  }): Promise<MediaAssetContract> {
    // Un dépôt rejoué après une coupure ne crée pas un second média :
    // l'identifiant vient de l'administration et fait foi.
    const existing = await this.repository.findById(input.id);
    if (existing !== null) {
      return this.present(existing);
    }

    this.assertAcceptable(input.kind, input.mimeType, input.content);

    const extension = EXTENSIONS[input.mimeType] ?? '';
    const key = StorageService.keyFor(input.kind, input.id, extension);
    const size = input.kind === 'IMAGE' ? readImageSize(input.content) : null;

    await this.storage.put(key, input.content, input.mimeType);

    const created = await this.repository.create({
      id: input.id,
      kind: input.kind,
      storageKey: key,
      mimeType: input.mimeType,
      byteSize: input.content.byteLength,
      width: size?.width ?? null,
      height: size?.height ?? null,
      checksum: createHash('sha256').update(input.content).digest('hex'),
      originalName: input.originalName,
      uploadedById: input.actor.adminUserId,
    });
    this.record('admin.media_uploaded', created.id, input.actor, {
      kind: input.kind,
      byteSize: created.byteSize,
    });
    return this.present(created);
  }

  async list(kind?: MediaKind): Promise<MediaAssetContract[]> {
    const rows = await this.repository.list(kind);
    return rows.map((row) => this.present(row));
  }

  /**
   * Suppression logique. L'objet reste en stockage tant qu'un exercice le
   * référence — sinon une photo disparaîtrait des applications déjà
   * installées sans que personne ne l'ait décidé.
   */
  async remove(id: string, actor: MediaActor): Promise<void> {
    const media = await this.repository.findById(id);
    if (media === null) {
      throw new NotFoundException('Média introuvable.');
    }

    const references = await this.repository.countReferences(id);
    if (references > 0) {
      throw new BadRequestException(
        `Ce média est utilisé par ${references} exercice(s). Détache-le d'abord.`,
      );
    }

    await this.repository.softDelete(id);
    await this.storage.delete(media.storageKey);
    this.record('admin.media_deleted', id, actor, { kind: media.kind });
  }

  /** Rattache un média à un exercice, ou l'en détache avec `null`. */
  async attachToExercise(
    exerciseId: string,
    role: 'image' | 'mesh',
    mediaId: string | null,
    actor: MediaActor,
  ): Promise<void> {
    if (mediaId !== null) {
      const media = await this.repository.findById(mediaId);
      if (media === null) {
        throw new NotFoundException('Média introuvable.');
      }
      // Un maillage à la place d'une photo produirait une fiche cassée : le
      // genre du média doit correspondre au rôle qu'on lui donne.
      const expected: MediaKind = role === 'image' ? 'IMAGE' : 'MESH_3D';
      if (media.kind !== expected) {
        throw new BadRequestException(`Un média « ${media.kind} » ne peut pas servir de ${role}.`);
      }
    }

    const updated = await this.repository.setExerciseMedia(exerciseId, role, mediaId);
    if (!updated) {
      throw new NotFoundException('Exercice introuvable.');
    }

    // Le catalogue est mis en cache : sans cette invalidation, une photo
    // rattachée n'apparaîtrait qu'à l'expiration du cache, soit une heure.
    await this.exercises.invalidateCache();
    this.audit.record({
      action: mediaId === null ? 'admin.exercise_media_detached' : 'admin.exercise_media_attached',
      actorType: 'ADMIN',
      adminUserId: actor.adminUserId,
      resourceType: 'exercise',
      resourceId: exerciseId,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
      metadata: { role, mediaId },
    });
  }

  private assertAcceptable(kind: MediaKind, mimeType: string, content: Buffer): void {
    if (content.byteLength === 0) {
      throw new BadRequestException('Fichier vide.');
    }
    if (content.byteLength > this.config.mediaMaxUploadBytes) {
      throw new PayloadTooLargeException(
        `Fichier trop lourd (max ${this.config.mediaMaxUploadBytes} octets).`,
      );
    }
    if (!MEDIA_ALLOWED_MIME_TYPES[kind].includes(mimeType)) {
      throw new UnsupportedMediaTypeException(`Type « ${mimeType} » refusé pour un média ${kind}.`);
    }
  }

  private record(
    action: string,
    mediaId: string,
    actor: MediaActor,
    metadata: Record<string, string | number>,
  ): void {
    this.audit.record({
      action,
      actorType: 'ADMIN',
      adminUserId: actor.adminUserId,
      resourceType: 'media',
      resourceId: mediaId,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
      metadata,
    });
  }

  private present(media: MediaAsset): MediaAssetContract {
    return {
      id: media.id,
      kind: media.kind,
      url: this.storage.urlFor(media.storageKey),
      mimeType: media.mimeType,
      byteSize: media.byteSize,
      width: media.width,
      height: media.height,
      originalName: media.originalName,
      createdAt: media.createdAt.toISOString(),
    };
  }
}
