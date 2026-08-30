import {
  FRIEND_CODE_ALPHABET,
  FRIEND_CODE_LENGTH,
  formatFriendCode,
  friendCodeQrPayload,
  generateFriendCode,
  normalizeFriendCode,
} from './friend-code';

describe('friend-code', () => {
  it('génère 8 caractères de l’alphabet, sans ambiguïté visuelle', () => {
    for (let i = 0; i < 200; i += 1) {
      const code = generateFriendCode();
      expect(code).toHaveLength(FRIEND_CODE_LENGTH);
      for (const char of code) {
        expect(FRIEND_CODE_ALPHABET).toContain(char);
      }
    }
    // L'alphabet lui-même ne contient aucun caractère confondable.
    for (const banned of '01BGILOQSZ') {
      expect(FRIEND_CODE_ALPHABET).not.toContain(banned);
    }
  });

  it('normalise la forme affichée, la casse, les espaces et le QR', () => {
    expect(normalizeFriendCode('AC23-DEF4')).toBe('AC23DEF4');
    expect(normalizeFriendCode('ac23def4')).toBe('AC23DEF4');
    expect(normalizeFriendCode('  AC23 DEF4 ')).toBe('AC23DEF4');
    expect(normalizeFriendCode('carlys:friend:AC23DEF4')).toBe('AC23DEF4');
  });

  it('refuse ce qui n’est pas un code', () => {
    expect(normalizeFriendCode('')).toBeNull();
    expect(normalizeFriendCode('AC23DEF')).toBeNull(); // trop court
    expect(normalizeFriendCode('AC23DEF45')).toBeNull(); // trop long
    expect(normalizeFriendCode('AC23DEF0')).toBeNull(); // 0 hors alphabet
    expect(normalizeFriendCode('AC23DEFO')).toBeNull(); // O hors alphabet
    expect(normalizeFriendCode('autre:qr:AC23DEF4')).toBeNull();
  });

  it('affiche en XXXX-XXXX et re-normalise à l’identique', () => {
    const code = generateFriendCode();
    expect(formatFriendCode(code)).toBe(`${code.slice(0, 4)}-${code.slice(4)}`);
    expect(normalizeFriendCode(formatFriendCode(code))).toBe(code);
  });

  it('le QR porte le préfixe Carlys et se re-normalise', () => {
    const code = generateFriendCode();
    expect(friendCodeQrPayload(code)).toBe(`carlys:friend:${code}`);
    expect(normalizeFriendCode(friendCodeQrPayload(code))).toBe(code);
  });
});
