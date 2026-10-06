import { InMemoryObjectStore } from '../../../../test/support/in-memory-object-store';
import {
  DEAD_SESSION_RETENTION_DAYS,
  type DeletedAccountsLedger,
  ORPHAN_PAYMENT_EVENT_RETENTION_DAYS,
  purgeDeletedAccounts,
  type SessionsPurged,
} from './deleted-accounts-purge';

/// CE QUE CE FICHIER PROTÈGE : la purge efface les comptes SUPPRIMÉS depuis
/// plus que le délai, photos privées d'abord, et rien d'autre.

const MAINTENANT = new Date('2026-09-25T12:00:00Z');

interface Supprime {
  readonly id: string;
  readonly deletedAt: Date;
}

function compte(id: string, joursDepuis: number): Supprime {
  return { id, deletedAt: new Date(MAINTENANT.getTime() - joursDepuis * 86_400_000) };
}

class FauxRegistre implements DeletedAccountsLedger {
  readonly effaces: string[] = [];
  readonly ordre: string[] = [];
  /** Réception des événements de paiement en échec qui ne nomment aucun compte. */
  constructor(
    private readonly comptes: Supprime[],
    public orphelins: Date[] = [],
    /** Fermeture des sessions closes, expiration des jetons. */
    public sessions: Date[] = [],
    public jetons: Date[] = [],
  ) {}

  countDeadSessionsBefore(before: Date): Promise<SessionsPurged> {
    return Promise.resolve({
      sessions: this.sessions.filter((d) => d < before).length,
      refreshTokens: this.jetons.filter((d) => d < before).length,
    });
  }

  async eraseDeadSessionsBefore(before: Date): Promise<SessionsPurged> {
    const compte = await this.countDeadSessionsBefore(before);
    this.sessions = this.sessions.filter((d) => d >= before);
    this.jetons = this.jetons.filter((d) => d >= before);
    return compte;
  }

  countOrphanPaymentEventsBefore(before: Date): Promise<number> {
    return Promise.resolve(this.orphelins.filter((recu) => recu < before).length);
  }

  eraseOrphanPaymentEventsBefore(before: Date): Promise<number> {
    const avant = this.orphelins.length;
    this.orphelins = this.orphelins.filter((recu) => recu >= before);
    return Promise.resolve(avant - this.orphelins.length);
  }

  listDeletedBefore(before: Date): Promise<string[]> {
    return Promise.resolve(
      this.comptes
        .filter((c) => c.deletedAt < before && !this.effaces.includes(c.id))
        .map((c) => c.id),
    );
  }

  isDeleted(id: string): Promise<boolean> {
    return Promise.resolve(this.comptes.some((c) => c.id === id));
  }

  eraseAccount(id: string): Promise<boolean> {
    this.ordre.push(`base ${id}`);
    this.effaces.push(id);
    return Promise.resolve(true);
  }
}

async function photo(store: InMemoryObjectStore, userId: string, nom: string): Promise<void> {
  await store.put(`meal-photos/${userId}/${nom}.jpg`, Buffer.from('x'), 'image/jpeg');
}

describe('purgeDeletedAccounts', () => {
  it('efface les comptes supprimés depuis plus que le délai, photos comprises, et eux seuls', async () => {
    const registre = new FauxRegistre([compte('ancien', 40), compte('recent', 5)]);
    const store = new InMemoryObjectStore();
    await photo(store, 'ancien', 'a');
    await photo(store, 'ancien', 'b');
    await photo(store, 'recent', 'c');

    const rapport = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      dryRun: false,
    });

    expect(rapport).toEqual({
      eligible: 1,
      erased: 1,
      objectsDeleted: 2,
      paymentEventsErased: 0,
      sessionsErased: { sessions: 0, refreshTokens: 0 },
      failures: [],
      refused: null,
    });
    expect(registre.effaces).toEqual(['ancien']);
    expect([...store.objects.keys()]).toEqual(['meal-photos/recent/c.jpg']);
  });

  it('à blanc : compte, n’efface rien', async () => {
    const registre = new FauxRegistre([compte('ancien', 40)]);
    const store = new InMemoryObjectStore();
    await photo(store, 'ancien', 'a');

    const rapport = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      dryRun: true,
    });

    expect(rapport.eligible).toBe(1);
    expect(registre.effaces).toEqual([]);
    expect(store.objects.size).toBe(1);
  });

  it('stockage en panne : la base n’est PAS effacée, le passage suivant réessaiera', async () => {
    const registre = new FauxRegistre([compte('ancien', 40)]);
    const store = new InMemoryObjectStore();
    await photo(store, 'ancien', 'a');
    store.failDeletes = true;

    const rapport = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      dryRun: false,
    });

    expect(rapport.erased).toBe(0);
    expect(rapport.failures).toHaveLength(1);
    expect(registre.effaces).toEqual([]);
  });

  it('--compte : efface tout de suite un compte supprimé, refuse un compte qui ne l’est pas', async () => {
    const registre = new FauxRegistre([compte('hier', 1)]);
    const store = new InMemoryObjectStore();

    const immediat = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      accountId: 'hier',
      dryRun: false,
    });
    expect(immediat.erased).toBe(1);

    const refus = await purgeDeletedAccounts(registre, store, {
      now: MAINTENANT,
      delayDays: 30,
      accountId: 'actif',
      dryRun: false,
    });
    expect(refus.refused).toContain('n’est pas un compte supprimé');
    expect(refus.erased).toBe(0);
  });

  it('événements de paiement en échec SANS compte : effacés après 90 jours, par la passe quotidienne', async () => {
    // `$RCAnonymousID`, charge sans `metadata.userId` : la purge d'un compte
    // ne les retrouve jamais, puisqu'ils n'en nomment aucun.
    const jours = (n: number) => new Date(MAINTENANT.getTime() - n * 86_400_000);
    expect(ORPHAN_PAYMENT_EVENT_RETENTION_DAYS).toBe(90);
    const registre = new FauxRegistre([compte('hier', 1)], [jours(91), jours(89)]);
    const store = new InMemoryObjectStore();
    const options = { now: MAINTENANT, delayDays: 30 };

    const simulation = await purgeDeletedAccounts(registre, store, { ...options, dryRun: true });
    expect(simulation.paymentEventsErased).toBe(1);
    expect(registre.orphelins).toHaveLength(2);

    // Un effacement ciblé (`--compte`) ne touche qu'à son compte.
    const cible = await purgeDeletedAccounts(registre, store, {
      ...options,
      accountId: 'hier',
      dryRun: false,
    });
    expect(cible.paymentEventsErased).toBe(0);
    expect(registre.orphelins).toHaveLength(2);

    const rapport = await purgeDeletedAccounts(registre, store, { ...options, dryRun: false });
    expect(rapport.paymentEventsErased).toBe(1);
    expect(registre.orphelins).toEqual([jours(89)]);
  });

  it('sessions closes et jetons échus : effacés après 30 jours, par la passe quotidienne', async () => {
    // Une ligne par rotation, jamais effacée hors suppression de compte.
    const jours = (n: number) => new Date(MAINTENANT.getTime() - n * 86_400_000);
    expect(DEAD_SESSION_RETENTION_DAYS).toBe(30);
    const registre = new FauxRegistre(
      [compte('hier', 1)],
      [],
      [jours(31), jours(29)],
      [jours(31), jours(31), jours(2)],
    );
    const store = new InMemoryObjectStore();
    const options = { now: MAINTENANT, delayDays: 30 };

    const simulation = await purgeDeletedAccounts(registre, store, { ...options, dryRun: true });
    expect(simulation.sessionsErased).toEqual({ sessions: 1, refreshTokens: 2 });
    expect(registre.jetons).toHaveLength(3);

    const cible = await purgeDeletedAccounts(registre, store, {
      ...options,
      accountId: 'hier',
      dryRun: false,
    });
    expect(cible.sessionsErased).toEqual({ sessions: 0, refreshTokens: 0 });
    expect(registre.sessions).toHaveLength(2);

    const rapport = await purgeDeletedAccounts(registre, store, { ...options, dryRun: false });
    expect(rapport.sessionsErased).toEqual({ sessions: 1, refreshTokens: 2 });
    expect(registre.sessions).toEqual([jours(29)]);
    expect(registre.jetons).toEqual([jours(2)]);
  });

  it('passe des sessions en panne : les comptes sont effacés quand même, l’échec est rapporté', async () => {
    const registre = new FauxRegistre([compte('ancien', 40)]);
    registre.eraseDeadSessionsBefore = () => Promise.reject(new Error('délai dépassé'));

    const rapport = await purgeDeletedAccounts(registre, new InMemoryObjectStore(), {
      now: MAINTENANT,
      delayDays: 30,
      dryRun: false,
    });

    expect(registre.effaces).toEqual(['ancien']);
    expect(rapport.sessionsErased).toEqual({ sessions: 0, refreshTokens: 0 });
    expect(rapport.failures).toEqual(['sessions closes : délai dépassé']);
  });
});
