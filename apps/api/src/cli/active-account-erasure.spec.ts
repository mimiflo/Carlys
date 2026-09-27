import { type INestApplicationContext } from '@nestjs/common';
import { AuditService } from '../modules/audit/audit.service';
import {
  AccountService,
  type WrittenRequestOutcome,
} from '../modules/auth/application/account.service';
import { deleteActiveAccount, formatWrittenRequest } from './active-account-erasure';

const COMPTE = '0b6f7a3c-1d2e-4f5a-8b9c-0d1e2f3a4b5c';

function build(outcome: WrittenRequestOutcome, audit = { echouees: 0, abandonnees: 0 }) {
  const ordre: string[] = [];
  const account = {
    deleteOnWrittenRequest: jest.fn(() => {
      ordre.push('suppression');
      return Promise.resolve(outcome);
    }),
  };
  const journal = {
    flush: jest.fn(() => {
      ordre.push('audit drainé');
      return Promise.resolve(audit);
    }),
  };
  const app = {
    get: (jeton: unknown) =>
      jeton === AccountService ? account : jeton === AuditService ? journal : null,
  } as unknown as INestApplicationContext;
  const sorties = { out: '', err: '' };
  const io = {
    out: (texte: string) => (sorties.out += texte),
    err: (texte: string) => (sorties.err += texte),
  };
  return { app, io, sorties, ordre, account, journal };
}

const SUPPRIME: WrittenRequestOutcome = {
  status: 'deleted',
  stripeSubscriptions: 1,
  storeSubscriptionStillActive: false,
};

describe('deleteActiveAccount (--compte-actif)', () => {
  it('supprimé : l’audit est DRAINÉ avant de rendre la main à l’effacement', async () => {
    const { app, io, ordre, account } = build(SUPPRIME);

    await expect(
      deleteActiveAccount(app, { id: COMPTE, confirmEmail: 'a@b.c' }, false, io),
    ).resolves.toBe('deleted');
    expect(ordre).toEqual(['suppression', 'audit drainé']);
    expect(account.deleteOnWrittenRequest).toHaveBeenCalledWith(
      COMPTE,
      'a@b.c',
      false,
      expect.stringMatching(/^cli-/),
    );
  });

  it('audit non écrit : rien n’est effacé, et la commande dit comment reprendre', async () => {
    const { app, io, sorties } = build(SUPPRIME, { echouees: 1, abandonnees: 0 });

    await expect(
      deleteActiveAccount(app, { id: COMPTE, confirmEmail: 'a@b.c' }, false, io),
    ).resolves.toBe(1);
    expect(sorties.err).toContain(`--compte ${COMPTE}`);
  });

  it('refus : code 2, la raison sur la sortie d’erreur ; à blanc : 0, sans drainage', async () => {
    const refus = build({ status: 'refused', reason: 'La confirmation ne correspond pas.' });
    await expect(
      deleteActiveAccount(refus.app, { id: COMPTE, confirmEmail: 'x@y.z' }, false, refus.io),
    ).resolves.toBe(2);
    expect(refus.sorties.err).toContain('ne correspond pas');

    const simulation = build({ ...SUPPRIME, status: 'planned' });
    await expect(
      deleteActiveAccount(
        simulation.app,
        { id: COMPTE, confirmEmail: 'a@b.c' },
        true,
        simulation.io,
      ),
    ).resolves.toBe(0);
    expect(simulation.journal.flush).not.toHaveBeenCalled();
  });

  it('le compte rendu d’une demande écrite dit ce qui est fait, et le magasin à résilier', () => {
    const simulation = formatWrittenRequest(
      { status: 'planned', stripeSubscriptions: 1, storeSubscriptionStillActive: true },
      COMPTE,
    );
    expect(simulation).toContain('RIEN n’a été supprimé');
    expect(simulation).toContain('abonnements Stripe à résilier : 1');
    expect(simulation).toContain('App Store ou Play Store');

    const fait = formatWrittenRequest(
      { status: 'deleted', stripeSubscriptions: 0, storeSubscriptionStillActive: false },
      COMPTE,
    );
    expect(fait).toContain(`Compte ${COMPTE} supprimé`);
    expect(fait).not.toContain('App Store');
  });
});
