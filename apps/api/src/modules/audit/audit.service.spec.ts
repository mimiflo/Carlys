import { type PinoLogger } from 'nestjs-pino';
import { type PrismaService } from '../../database/prisma/prisma.service';
import { AuditService } from './audit.service';

/**
 * CE QUE CE FICHIER PROTÈGE : une écriture d'audit lancée n'est pas perdue.
 *
 * `record` est volontairement NON BLOQUANT — un journal de sécurité ne doit
 * pas faire échouer ni ralentir l'opération métier. La promesse était
 * toutefois simplement abandonnée (`void`), avec deux conséquences :
 * à l'arrêt du conteneur — à chaque déploiement — les écritures en vol
 * partaient avec le processus ; et les tests e2e qui relisaient la ligne
 * juste après la réponse HTTP tombaient par intermittence en CI.
 *
 * `flush()` attend ce qui est en vol, et `onModuleDestroy` l'appelle.
 *
 * COMMENT L'ATTENTE EST VÉRIFIÉE, et pourquoi pas autrement. Une première
 * version de ces tests posait un drapeau puis comptait les tours de
 * microtâches (`await Promise.resolve()`) avant de le relire. Deux d'entre
 * eux ne distinguaient alors RIEN : remettre le `void` d'origine les laissait
 * verts. On enregistre donc l'ORDRE des événements, et on draine
 * complètement la file de microtâches (`setImmediate`) avant de débloquer la
 * base : « flush a rendu la main avant que l'écriture soit posée » devient
 * alors une affirmation vérifiable, pas une question de cadence.
 */

/** Rend la main après avoir vidé TOUTE la file de microtâches en attente. */
const toutesMicrotaches = (): Promise<void> =>
  new Promise((resolve) => {
    setImmediate(resolve);
  });

interface Banc {
  service: AuditService;
  /** Débloque la n-ième écriture (1 = la première) et le note. */
  poser: (rang: number) => void;
  /** Ce qui s'est produit, dans l'ordre. */
  ordre: string[];
  create: jest.Mock;
  logger: { info: jest.Mock; error: jest.Mock };
}

function banc(): Banc {
  const ordre: string[] = [];
  const verrous: (() => void)[] = [];
  const create = jest.fn(
    () =>
      new Promise((resolve) => {
        verrous.push(() => {
          resolve(undefined);
        });
      }),
  );
  const logger = { info: jest.fn(), error: jest.fn() };

  const service = new AuditService(
    { auditLog: { create } } as unknown as PrismaService,
    logger as unknown as PinoLogger,
  );
  return {
    service,
    poser: (rang) => {
      ordre.push(`écriture ${rang}`);
      verrous[rang - 1]?.();
    },
    ordre,
    create,
    logger,
  };
}

describe('AuditService', () => {
  it('record ne bloque PAS l’appelant', async () => {
    // La garantie d'origine, vérifiée en premier : c'est elle qu'on ne veut
    // surtout pas perdre en ajoutant le registre des écritures en vol.
    const b = banc();

    b.service.record({ action: 'auth.login' });

    // L'écriture est partie, personne ne l'a posée, et on est déjà revenu ici.
    expect(b.create).toHaveBeenCalledTimes(1);
    await toutesMicrotaches();
    expect(b.logger.info).not.toHaveBeenCalled();
  });

  it('flush rend la main APRÈS que l’écriture est posée, jamais avant', async () => {
    const b = banc();

    b.service.record({ action: 'auth.refresh_reuse_detected' });
    const attente = b.service.flush().then(() => b.ordre.push('flush'));

    // Tous les tours de microtâches sont consommés : si flush avait rendu la
    // main sans rien attendre, « flush » serait DÉJÀ dans l'ordre.
    await toutesMicrotaches();
    expect(b.ordre).toEqual([]);

    b.poser(1);
    await attente;
    expect(b.ordre).toEqual(['écriture 1', 'flush']);
  });

  it('flush attend aussi une écriture lancée PENDANT son attente', async () => {
    // La boucle de `flush` sert à ça. Sans elle, la seconde écriture serait
    // relâchée dans le vide — et « flush » tomberait entre les deux.
    const b = banc();
    b.service.record({ action: 'un' });
    const attente = b.service.flush().then(() => b.ordre.push('flush'));

    await toutesMicrotaches();
    b.service.record({ action: 'deux' });
    b.poser(1);
    await toutesMicrotaches();
    b.poser(2);

    await attente;
    expect(b.ordre).toEqual(['écriture 1', 'écriture 2', 'flush']);
  });

  it('sans rien en vol, flush rend la main tout de suite', async () => {
    await expect(banc().service.flush()).resolves.toEqual({ abandonnees: 0, echouees: 0 });
  });

  it('une écriture qui ÉCHOUE est journalisée et ne fait pas échouer flush', async () => {
    // L'autre moitié du contrat : un échec d'audit ne remonte jamais à
    // l'appelant. Si `flush` rejetait, `onModuleDestroy` ferait échouer un
    // arrêt propre à cause d'une ligne de journal.
    const create = jest.fn().mockRejectedValue(new Error('base indisponible'));
    const logger = { info: jest.fn(), error: jest.fn() };
    const service = new AuditService(
      { auditLog: { create } } as unknown as PrismaService,
      logger as unknown as PinoLogger,
    );

    service.record({ action: 'auth.login' });

    // `flush` ne rejette pas — mais il ne PRÉTEND plus que la ligne est
    // posée. C'est toute la différence entre « la tentative est finie » et
    // « la ligne est là » : sans `echouees`, une violation de clé étrangère
    // ou un pool saturé rendrait un flush parfaitement normal suivi d'une
    // relecture vide, c'est-à-dire le symptôme EXACT de la course que flush
    // corrige — et le prochain échec serait diagnostiqué à tort.
    await expect(service.flush()).resolves.toEqual({ abandonnees: 0, echouees: 1 });
    expect(logger.error).toHaveBeenCalled();

    // Le compteur se PRÉLÈVE : un second flush ne réclame pas deux fois le
    // même échec, sinon un appelant qui draine en boucle croirait la base en
    // train de refuser sans arrêt.
    await expect(service.flush()).resolves.toEqual({ abandonnees: 0, echouees: 0 });
  });

  it('un arrêt SOUS CHARGE se termine au lieu de tourner sans fin', async () => {
    // LE DÉFAUT QUE CE TEST FERME. Dans `@nestjs/core` 11, `close()` exécute
    // `callDestroyHook()` AVANT `dispose()` : le serveur HTTP est encore
    // OUVERT quand `onModuleDestroy` draine. Un déploiement sous charge —
    // le cas normal ici — voit donc arriver des requêtes pendant le
    // drainage, et chacune rappelle `record`. Sans borne, `enVol` n'est
    // jamais vide à un point de contrôle, la boucle ne rend jamais la main,
    // et le conteneur est tué au bout du délai de l'orchestrateur : le
    // SIGKILL emporte alors exactement les écritures que ce drainage
    // existe pour sauver.
    //
    // On reproduit le pire cas : CHAQUE écriture posée en déclenche une
    // autre, donc la file se remplit aussi vite qu'elle se vide et ne peut
    // jamais atteindre zéro.
    const logger = { info: jest.fn(), error: jest.fn() };
    let lancees = 0;
    // La charge simulée est BORNÉE — largement au-delà de ce que le drainage
    // s'autorise, mais bornée : sans ce plafond, le nourrisseur continue
    // après le retour de `flush` et sature la mémoire du processus de test.
    // C'est arrivé à l'écriture de ce test, et c'est la démonstration en
    // creux du défaut corrigé : une file qui se réalimente toute seule ne
    // s'arrête pas d'elle-même.
    const CHARGE_MAX = 200;
    const create: jest.Mock<Promise<unknown>, []> = jest.fn(() => {
      lancees += 1;
      if (lancees < CHARGE_MAX) {
        // Le rappel est posé pour APRÈS la résolution : l'écriture suivante
        // entre dans `enVol` pendant que le drainage attend celle-ci.
        queueMicrotask(() => {
          service.record({ action: 'auth.login' });
        });
      }
      return Promise.resolve(undefined);
    });
    // `const` alors que `create` s'y réfère : la référence n'est LUE qu'au
    // premier appel, bien après l'initialisation.
    const service = new AuditService(
      { auditLog: { create } } as unknown as PrismaService,
      logger as unknown as PinoLogger,
    );

    service.record({ action: 'auth.login' });

    // Sans borne, cet `await` ne rendrait JAMAIS la main : le test tomberait
    // sur le délai d'expiration de Jest au lieu de cette assertion.
    const resultat = await service.flush();

    expect(resultat.abandonnees).toBeGreaterThan(0);
    expect(logger.error).toHaveBeenCalledWith(
      expect.objectContaining({ abandonnees: expect.any(Number) as number }),
      expect.stringContaining('abandonné'),
    );
    // La borne est un nombre de TOURS, pas un plafond d'écritures : on
    // vérifie seulement qu'elle a coupé, et qu'elle a coupé large — un
    // drainage qui renoncerait au premier tour ne draînerait rien.
    expect(lancees).toBeGreaterThan(1);
  });

  it('onModuleDestroy attend, lui aussi : un arrêt ne perd rien', async () => {
    const b = banc();

    b.service.record({ action: 'admin.community_report_resolved' });
    const arret = b.service.onModuleDestroy().then(() => b.ordre.push('arrêt'));

    await toutesMicrotaches();
    expect(b.ordre).toEqual([]);

    b.poser(1);
    await arret;
    expect(b.ordre).toEqual(['écriture 1', 'arrêt']);
  });
});
