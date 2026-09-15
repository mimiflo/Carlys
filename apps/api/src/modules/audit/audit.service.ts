import { Injectable, type OnModuleDestroy } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { type DrainageResult, TravauxEnVol } from '../../common/async/travaux-en-vol';
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

/** Ce qu'un drainage d'audit a réellement obtenu. */
export type AuditFlushResult = DrainageResult;

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
   *
   * Le registre lui-même vit dans `common/async/travaux-en-vol.ts` : l'envoi
   * d'e-mail avait le même défaut, et le raisonnement sur la BORNE du
   * drainage est trop délicat pour exister en deux exemplaires.
   */
  private readonly enVol: TravauxEnVol;

  constructor(
    private readonly prisma: PrismaService,
    @InjectPinoLogger(AuditService.name)
    private readonly logger: PinoLogger,
  ) {
    this.enVol = new TravauxEnVol('audit', logger);
  }

  record(entry: AuditEntry): void {
    this.enVol.suivre(
      this.prisma.auditLog.create({
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
      }),
      {
        succes: () => {
          this.logger.info({ action: entry.action, userId: entry.userId }, 'Événement de sécurité');
        },
        echec: (erreur) => {
          this.logger.error({ err: erreur, action: entry.action }, "Échec d'écriture de l'audit");
        },
      },
    );
  }

  /**
   * Attend que les écritures en vol soient posées, et rend ce qu'il en est.
   *
   * `abandonnees` non nul veut dire que la file se remplissait plus vite
   * qu'elle ne se vidait ; `echouees` non nul, que la base a REFUSÉ des
   * lignes — la relecture sera vide, et ce n'est pas une course. Voir
   * `TravauxEnVol` pour la borne du drainage.
   */
  flush(): Promise<AuditFlushResult> {
    return this.enVol.drainer();
  }

  /** Arrêt propre : ce qui est en vol se pose avant que le processus parte. */
  async onModuleDestroy(): Promise<void> {
    await this.flush();
  }
}
