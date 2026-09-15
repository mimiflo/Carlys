/**
 * Les travaux lancés SANS être attendus — et de quoi les attendre quand même.
 *
 * POURQUOI CE FICHIER EXISTE. Deux services du dépôt rendent la main sans
 * attendre ce qu'ils ont lancé, et pour de bonnes raisons : l'écriture du
 * journal d'audit ne doit ni ralentir ni faire échouer l'opération métier,
 * et l'envoi d'un e-mail transactionnel non plus. La contrepartie est la
 * même dans les deux cas : à l'arrêt du conteneur — c'est-à-dire à CHAQUE
 * déploiement —, ce qui est encore en vol part avec le processus.
 *
 * Pour l'audit, cela perdait des événements de sécurité au moment précis du
 * redéploiement. Pour l'e-mail, cela perd le lien de vérification d'adresse
 * ou de réinitialisation de mot de passe d'une personne qui vient de
 * recevoir un 200 : elle attend un courrier qui ne viendra jamais, et rien
 * à l'écran ne le lui dira.
 *
 * Le registre était écrit dans `AuditService` seul. Le recopier dans
 * `EmailService` aurait donné deux versions d'un raisonnement délicat — la
 * borne du drainage ci-dessous en est un — vouées à diverger. Il vit donc
 * ici, avec son argumentaire, une fois.
 */
import type { PinoLogger } from 'nestjs-pino';

/** Ce qu'un drainage a réellement obtenu. */
export interface DrainageResult {
  /**
   * Travaux encore en vol quand le drainage a renoncé. `0` : tout est posé.
   * Non nul, c'est que la file se remplissait plus vite qu'elle ne se vidait.
   */
  abandonnees: number;
  /**
   * Travaux qui ont ÉCHOUÉ depuis le drainage précédent. Non nul, l'effet
   * attendu n'a pas eu lieu — et ce n'est pas une course, c'est un échec.
   */
  echouees: number;
}

/** Ce que l'appelant veut journaliser de l'issue d'un travail. */
export interface JournalDuTravail {
  succes: () => void;
  echec: (erreur: unknown) => void;
}

export class TravauxEnVol {
  /**
   * Tours de drainage qu'un appel à [drainer] s'autorise.
   *
   * POURQUOI C'EST BORNÉ, et pourquoi en TOURS. Dans `@nestjs/core` 11,
   * `close()` exécute `callDestroyHook()` AVANT `dispose()` — vérifiable
   * dans `nest-application-context.js` : le serveur HTTP est donc ENCORE
   * OUVERT quand `onModuleDestroy` draine. Un déploiement sous charge — le
   * cas normal ici — voit arriver des requêtes pendant le drainage, et
   * chacune peut relancer un travail. Sans borne, la file n'est jamais vide
   * à un point de contrôle, le drainage ne rend jamais la main, le conteneur
   * ne s'arrête pas — jusqu'au SIGKILL de l'orchestrateur, qui emporte
   * précisément ce que le drainage existe pour sauver, et fait traîner le
   * déploiement par-dessus le marché.
   *
   * Le compte de TOURS est la bonne borne, pas un délai : chaque tour attend
   * l'instantané courant, donc un tour de plus ne sert qu'aux travaux
   * apparus PENDANT l'attente. Au-delà de quelques tours, ce n'est plus un
   * drainage qui se termine, c'est une file alimentée plus vite qu'elle ne
   * se vide — mieux vaut le DIRE et partir que s'arrêter au couteau. En
   * test, où rien n'arrive en parallèle, deux tours suffisent toujours : la
   * borne y est invisible.
   */
  static readonly TOURS_MAX = 20;

  private readonly enVol = new Set<Promise<void>>();
  private echouees = 0;

  /**
   * [quoi] nomme ce qui est drainé dans le journal technique — « audit »,
   * « e-mail » —, et n'atteint jamais l'utilisateur.
   */
  constructor(
    private readonly quoi: string,
    private readonly logger: PinoLogger,
  ) {}

  /**
   * Suit un travail déjà lancé. La promesse rendue par [travail] est
   * TERMINÉE ici : elle ne rejette jamais vers l'appelant, conformément au
   * contrat « un échec ne fait pas échouer l'opération métier ».
   */
  suivre(travail: Promise<unknown>, journal: JournalDuTravail): void {
    const suivi: Promise<void> = travail
      .then(() => {
        journal.succes();
      })
      .catch((erreur: unknown) => {
        this.echouees += 1;
        journal.echec(erreur);
      })
      .finally(() => {
        this.enVol.delete(suivi);
      });
    this.enVol.add(suivi);
  }

  /** Y a-t-il encore quelque chose en vol ? (Diagnostic et tests.) */
  get enCours(): number {
    return this.enVol.size;
  }

  /**
   * Attend ce qui est en vol, et rend ce qu'il en est.
   *
   * La boucle est voulue : un travail peut en avoir déclenché un autre
   * pendant l'attente. Aucune de ces promesses ne rejette — [suivre] les a
   * déjà toutes terminées — donc l'attente ne peut pas échouer, seulement se
   * terminer. Elle est bornée par [TOURS_MAX], voir là-haut.
   */
  async drainer(): Promise<DrainageResult> {
    let tours = 0;
    while (this.enVol.size > 0) {
      if (tours >= TravauxEnVol.TOURS_MAX) {
        const abandonnees = this.enVol.size;
        this.logger.error(
          { quoi: this.quoi, abandonnees, tours },
          'Drainage abandonné : la file se remplit plus vite qu’elle ne se vide',
        );
        return { abandonnees, echouees: this.preleverEchecs() };
      }
      tours += 1;
      await Promise.all([...this.enVol]);
    }
    return { abandonnees: 0, echouees: this.preleverEchecs() };
  }

  /** Le compteur se PRÉLÈVE : un drainage rend ce qui s'est passé DEPUIS le précédent. */
  private preleverEchecs(): number {
    const echecs = this.echouees;
    this.echouees = 0;
    return echecs;
  }
}
