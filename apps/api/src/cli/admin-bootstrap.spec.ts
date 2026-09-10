import {
  PASSWORD_MIN_LENGTH,
  UsageError,
  generatePassword,
  parseArgs,
  validatePassword,
} from './admin-bootstrap';

describe('admin-bootstrap — arguments', () => {
  it('exige une adresse en premier argument', () => {
    expect(() => parseArgs([])).toThrow(UsageError);
    expect(() => parseArgs(['--role', 'support'])).toThrow(UsageError);
  });

  it('refuse une adresse invalide', () => {
    expect(() => parseArgs(['pas-une-adresse'])).toThrow(/invalide/);
  });

  it('normalise l’adresse et dérive un nom d’affichage', () => {
    const args = parseArgs(['  Ops@Carlys.APP ']);
    expect(args).toEqual({
      email: 'ops@carlys.app',
      role: 'superadmin',
      displayName: 'ops',
      resetPassword: false,
    });
  });

  it('accepte un rôle connu et refuse un rôle inconnu', () => {
    expect(parseArgs(['a@b.fr', '--role', 'support']).role).toBe('support');
    expect(() => parseArgs(['a@b.fr', '--role', 'dieu'])).toThrow(/--role attend/);
    expect(() => parseArgs(['a@b.fr', '--role'])).toThrow(/--role attend/);
  });

  it('lit le nom d’affichage et le drapeau de réinitialisation', () => {
    const args = parseArgs(['a@b.fr', '--display-name', ' Florian ', '--reset-password']);
    expect(args.displayName).toBe('Florian');
    expect(args.resetPassword).toBe(true);
  });

  it('refuse une option inconnue', () => {
    expect(() => parseArgs(['a@b.fr', '--force'])).toThrow(/Option inconnue/);
  });
});

describe('admin-bootstrap — mot de passe', () => {
  it('engendre 24 caractères sans espace ni ambiguïté de forme', () => {
    const password = generatePassword();
    expect(password).toHaveLength(24);
    expect(password).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(validatePassword(password)).toBeNull();
  });

  it('refuse un mot de passe plus court que le minimum', () => {
    expect(validatePassword('a'.repeat(PASSWORD_MIN_LENGTH - 1))).toMatch(/trop court/);
    expect(validatePassword('a'.repeat(PASSWORD_MIN_LENGTH))).toBeNull();
  });
});
