import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PrismaService } from '../../database/prisma/prisma.service';

export interface AuditEntry {
  action: string;
  userId?: string;
  /** USER par défaut ; ADMIN pour les actions du back-office. */
  actorType?: 'USER' | 'ADMIN' | 'SYSTEM';
  adminUserId?: string;
  /** Référence LOGIQUE de la ressource touchée (sans clé étrangère). */
  resourceType?: string;
  resourceId?: string;
  /** Corrélation avec les logs Pino et l'en-tête x-request-id. */
  requestId?: string;
  ipAddress?: string;
  userAgent?: string;
  /** Contexte non sensible uniquement — jamais de mot de passe ni de jeton. */
  metadata?: Record<string, string | number | boolean | null>;
}

/**
 * Journal d'audit des événements de sécurité (persisté en base).
 * L'écriture n'est jamais bloquante pour la requête : un échec d'audit est
 * loggé mais ne fait pas échouer l'opération métier.
 */
@Injectable()
export class AuditService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectPinoLogger(AuditService.name)
    private readonly logger: PinoLogger,
  ) {}

  record(entry: AuditEntry): void {
    void this.prisma.auditLog
      .create({
        data: {
          action: entry.action,
          actorType: entry.actorType ?? 'USER',
          userId: entry.userId ?? null,
          adminUserId: entry.adminUserId ?? null,
          resourceType: entry.resourceType ?? null,
          resourceId: entry.resourceId ?? null,
          requestId: entry.requestId ?? null,
          ipAddress: entry.ipAddress ?? null,
          userAgent: entry.userAgent ?? null,
          metadata: entry.metadata ?? undefined,
        },
      })
      .then(() => {
        this.logger.info({ action: entry.action, userId: entry.userId }, 'Événement de sécurité');
      })
      .catch((error: unknown) => {
        this.logger.error({ err: error, action: entry.action }, "Échec d'écriture de l'audit");
      });
  }
}
