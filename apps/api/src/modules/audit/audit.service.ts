import { Injectable, type OnModuleDestroy } from '@nestjs/common';
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
export class AuditService implements OnModuleDestroy {
  /**
   * Les écritures EN VOL, celles que `record` a lancées sans les attendre.
   *
   * Sans ce registre, la promesse était simplement abandonnée (`void`), avec
   * deux conséquences qui n'ont pas le même poids mais la même cause.
   *
   * En PRODUCTION : à l'arrêt du conteneur — c'est-à-dire à CHAQUE
   * déploiement, plusieurs fois par jour ici — les écritures encore en vol
   * disparaissaient avec le processus. Perdre en silence des événements de
   * sécurité (réutilisation de jeton détectée, action d'administration) au
   * moment précis où l'on redéploie est exactement ce qu'un journal d'audit
   * ne doit pas faire.
   *
   * En TEST : un e2e qui agit puis relit la ligne d'audit courait contre
   * cette promesse. Deux tests tombaient par intermittence en CI
   * (`auth.refresh_reuse_detected`, `admin.community_report_resolved`) sans
   * qu'aucun code de production n'ait changé. Un test qui échoue au hasard
   * finit par être ignoré, et ce jour-là il ne garde plus rien.
   *
   * Le contrat public ne change pas : `record` reste non bloquant, et un
   * échec d'écriture reste journalisé sans faire échouer l'opération métier.
   */
  private readonly enVol = new Set<Promise<void>>();

  constructor(
    private readonly prisma: PrismaService,
    @InjectPinoLogger(AuditService.name)
    private readonly logger: PinoLogger,
  ) {}

  record(entry: AuditEntry): void {
    const ecriture: Promise<void> = this.prisma.auditLog
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
      })
      .finally(() => {
        this.enVol.delete(ecriture);
      });
    this.enVol.add(ecriture);
  }

  /**
   * Attend que les écritures en vol soient posées.
   *
   * La boucle est voulue : une écriture peut en avoir déclenché une autre
   * pendant l'attente. Aucune de ces promesses ne rejette — `record` les a
   * déjà toutes terminées par un `catch` — donc l'attente ne peut pas
   * échouer, seulement se terminer.
   */
  async flush(): Promise<void> {
    while (this.enVol.size > 0) {
      await Promise.all([...this.enVol]);
    }
  }

  /** Arrêt propre : ce qui est en vol se pose avant que le processus parte. */
  async onModuleDestroy(): Promise<void> {
    await this.flush();
  }
}
