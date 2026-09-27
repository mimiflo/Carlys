import { createHash } from 'node:crypto';
import { logFingerprint, withoutEmails } from './log-privacy';

/**
 * CE QUE CE FICHIER PROTÈGE : l'empreinte d'une adresse ne se renverse pas
 * par dictionnaire. Un SHA-256 nu, même tronqué, se recalculait sur une
 * liste d'adresses candidates (deux millions en quatre secondes, aucune
 * collision) : l'audit, qui survit aux comptes, redevenait un annuaire.
 */
describe('logFingerprint', () => {
  const cle = Buffer.from('cle-du-serveur');

  it('stable pour une même clé : la corrélation entre lignes reste possible', () => {
    expect(logFingerprint('alice@b.fr', cle)).toBe(logFingerprint('alice@b.fr', cle));
    expect(logFingerprint('alice@b.fr', cle)).toMatch(/^[0-9a-f]{12}$/);
  });

  it('sans la clé, une adresse candidate ne se vérifie pas', () => {
    const empreinte = logFingerprint('alice@b.fr', cle);
    const hachageNu = createHash('sha256').update('alice@b.fr').digest('hex').slice(0, 12);
    expect(empreinte).not.toBe(hachageNu);
    expect(empreinte).not.toBe(logFingerprint('alice@b.fr', Buffer.from('autre-cle')));
  });
});

describe('withoutEmails', () => {
  it('retire les adresses d’un refus SMTP', () => {
    expect(withoutEmails('550 <nom@exemple.fr>: Recipient address rejected')).toBe(
      '550 <<adresse>>: Recipient address rejected',
    );
  });
});
