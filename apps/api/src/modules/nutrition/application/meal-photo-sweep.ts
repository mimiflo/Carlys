import { type PrivateObjectStore } from '../../../infrastructure/storage/private-object-store';
import { MEAL_PHOTO_PREFIX } from '../domain/meal-photo-key';
import { type MealPhotoLedger } from '../infrastructure/meal-photo-ledger';

/**
 * Délai de grâce par défaut : un objet plus jeune n'est jamais pris pour un
 * orphelin. Un dépôt écrit l'objet PUIS la ligne ; entre les deux, l'objet
 * n'est cité par rien, et le balayer à ce moment-là supprimerait une photo
 * en train d'être enregistrée. Une heure couvre très largement cet écart.
 */
export const DEFAULT_SWEEP_GRACE_MS = 60 * 60 * 1000;

export interface SweepOptions {
  readonly now: Date;
  readonly graceMs: number;
  /** Compte sans rien effacer. */
  readonly dryRun: boolean;
}

export interface SweepReport {
  readonly scanned: number;
  readonly live: number;
  /** Orphelins épargnés parce que trop récents (délai de grâce). */
  readonly young: number;
  readonly orphans: number;
  readonly deleted: number;
  /** Effacements qui ont échoué : à relancer, la commande sort en erreur. */
  readonly failures: readonly string[];
}

/**
 * Balaye les photos de repas ORPHELINES du bucket privé et les efface.
 *
 * Une seule règle, celle du modèle `MealPhoto` : un objet est vivant si et
 * seulement si la ligne d'un repas non supprimé le cite. Elle rattrape
 * d'un coup tous les chemins qui peuvent laisser un objet derrière eux :
 * effacement raté après la suppression d'un repas ou d'une photo, ancienne
 * photo non effacée après un remplacement, dépôt dont la ligne n'a jamais
 * été écrite, suppression de compte dont le stockage n'a pas répondu.
 *
 * Rejouable à volonté : un second passage ne trouve plus rien à effacer.
 */
export async function sweepOrphanMealPhotos(
  store: PrivateObjectStore,
  ledger: MealPhotoLedger,
  options: SweepOptions,
): Promise<SweepReport> {
  const failures: string[] = [];
  let scanned = 0;
  let live = 0;
  let young = 0;
  let orphans = 0;
  let deleted = 0;
  let cursor: string | null = null;
  do {
    const page = await store.list(MEAL_PHOTO_PREFIX, cursor);
    const alive = await ledger.liveKeysAmong(page.objects.map((object) => object.key));
    const erased: string[] = [];
    for (const object of page.objects) {
      scanned += 1;
      if (alive.has(object.key)) {
        live += 1;
      } else if (options.now.getTime() - object.lastModified.getTime() < options.graceMs) {
        young += 1;
      } else {
        orphans += 1;
        if (!options.dryRun) {
          try {
            await store.delete(object.key);
            erased.push(object.key);
            deleted += 1;
          } catch (error) {
            failures.push(`${object.key} : ${(error as Error).message}`);
          }
        }
      }
    }
    await ledger.forgetKeys(erased);
    cursor = page.next;
  } while (cursor !== null);
  return { scanned, live, young, orphans, deleted, failures };
}
