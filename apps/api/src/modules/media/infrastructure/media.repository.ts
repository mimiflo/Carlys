import { Injectable } from '@nestjs/common';
import { type MediaAsset, type MediaKind } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Accès Prisma des médias — et de lui seul. */
@Injectable()
export class MediaRepository {
  constructor(private readonly prisma: PrismaService) {}

  findById(id: string): Promise<MediaAsset | null> {
    return this.prisma.mediaAsset.findFirst({ where: { id, deletedAt: null } });
  }

  list(kind?: MediaKind): Promise<MediaAsset[]> {
    return this.prisma.mediaAsset.findMany({
      where: { deletedAt: null, ...(kind === undefined ? {} : { kind }) },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  create(data: {
    id: string;
    kind: MediaKind;
    storageKey: string;
    mimeType: string;
    byteSize: number;
    width: number | null;
    height: number | null;
    checksum: string;
    originalName: string;
    uploadedById: string;
  }): Promise<MediaAsset> {
    return this.prisma.mediaAsset.create({ data });
  }

  /** Combien d'exercices référencent ce média, tous rôles confondus. */
  async countReferences(mediaId: string): Promise<number> {
    return this.prisma.exercise.count({
      where: { OR: [{ imageId: mediaId }, { meshId: mediaId }] },
    });
  }

  async softDelete(id: string): Promise<void> {
    await this.prisma.mediaAsset.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  /** Rend `false` si l'exercice n'existe pas. */
  async setExerciseMedia(
    exerciseId: string,
    role: 'image' | 'mesh',
    mediaId: string | null,
  ): Promise<boolean> {
    const result = await this.prisma.exercise.updateMany({
      where: { id: exerciseId },
      data: role === 'image' ? { imageId: mediaId } : { meshId: mediaId },
    });
    return result.count > 0;
  }
}
