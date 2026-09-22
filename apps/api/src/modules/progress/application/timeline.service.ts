import { type ProgressEvent, type ProgressTimeline } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { ProgressRepository } from '../infrastructure/progress.repository';
import { decodeTimelineCursor, encodeTimelineCursor } from './timeline-cursor';

/**
 * LA FRISE : ce qui s'est passé, dans l'ordre, et ce qu'on en reprend d'un
 * appareil.
 *
 * Un service à part de `ProgressService`, qui porte déjà les records, les
 * statistiques et les mesures corporelles : la frise LIT ces trois-là sans
 * jamais les écrire, et les mêler aurait fait d'un fichier déjà dense le
 * point de passage de deux domaines.
 */
@Injectable()
export class TimelineService {
  constructor(private readonly progress: ProgressRepository) {}

  /**
   * LA FRISE, une page à la fois.
   *
   * Le curseur encode le COUPLE `(occurredAt, id)` en base64, pas l'id seul :
   * un flux fusionné de quatre sources a des ex æquo à la milliseconde, et
   * un curseur sur l'id sauterait des lignes. Un curseur illisible est
   * traité comme absent — on repart du début plutôt que de refuser une
   * lecture, un curseur étant une position, pas une autorisation.
   *
   * Les EN-TÊTES DE MOIS se posent côté client. Découpés ici, une page
   * vaudrait deux lignes ou deux cents selon le mois ; le serveur pagine par
   * compte d'éléments, et le client ouvre un en-tête quand le mois change,
   * y compris à cheval sur deux pages.
   */
  async timeline(
    userId: string,
    options: { limit: number; kinds: string[]; cursor?: string },
  ): Promise<ProgressTimeline> {
    const depuis = decodeTimelineCursor(options.cursor);
    // Une ligne de plus que demandé : c'est elle qui dit `hasMore` sans
    // compter la table entière.
    const rows = await this.progress.timeline(userId, options.limit + 1, options.kinds, depuis);
    const page = rows.slice(0, options.limit);
    const hasMore = rows.length > options.limit;
    const dernier = page.at(-1);

    return {
      items: page.map((row) => ({
        id: `${row.kind}:${row.id}`,
        kind: row.kind as ProgressEvent['kind'],
        occurredAt: row.occurredAt.toISOString(),
        payload: (row.payload ?? {}) as Record<string, unknown>,
      })),
      nextCursor:
        hasMore && dernier !== undefined
          ? encodeTimelineCursor(dernier.occurredAt, dernier.id)
          : null,
      hasMore,
    };
  }

  /**
   * Reprend le journal de récompenses d'un appareil.
   *
   * Les records ne s'importent PAS : ils se dérivent des séries, et les
   * accepter d'un client laisserait inventer un franchissement qu'aucune
   * série ne justifie.
   */
  async importMilestones(
    userId: string,
    milestones: ReadonlyArray<{ kind: 'REWARD' | 'TITLE'; key: string; occurredAt: Date }>,
  ): Promise<void> {
    await this.progress.importMilestones(userId, milestones);
  }
}
