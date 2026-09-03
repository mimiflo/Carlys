import { normalizeFriendCode } from './friend-code';
import { tombstoneEmail, tombstoneFriendCode } from './tombstone';

const USER_ID = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

describe('Valeurs tombales', () => {
  it('l’adresse tombale libère l’adresse d’origine et ne peut jamais recevoir de courrier', () => {
    const email = tombstoneEmail(USER_ID);

    expect(email).toBe(`supprime+${USER_ID}@carlys.invalid`);
    // Unique par construction : deux comptes supprimés ne se heurtent pas.
    expect(tombstoneEmail('autre-id')).not.toBe(email);
  });

  it('le code ami tombal n’est pas un code ami : aucun scan ni aucune saisie ne le résout', () => {
    const code = tombstoneFriendCode(USER_ID);

    expect(normalizeFriendCode(code)).toBeNull();
    expect(tombstoneFriendCode('autre-id')).not.toBe(code);
  });
});
