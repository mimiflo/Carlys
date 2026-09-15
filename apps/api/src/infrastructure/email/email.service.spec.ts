/**
 * CE QUE CE FICHIER PROTÈGE : un e-mail de vérification ou de
 * réinitialisation lancé n'est pas perdu à l'arrêt du conteneur.
 *
 * `send` est volontairement NON BLOQUANT — un serveur SMTP lent ne doit pas
 * retenir une inscription. Mais la promesse de `sendMail` était simplement
 * abandonnée (`void … .then().catch()`), et `onModuleDestroy` fermait le
 * transporteur sans rien attendre. À chaque déploiement — plusieurs par jour
 * ici —, une inscription servie dans la seconde qui précède l'arrêt partait
 * en vol, le transporteur se fermait, le processus mourait : la personne
 * recevait un 200 et n'a jamais reçu son lien.
 *
 * POURQUOI CE FICHIER N'EXISTAIT PAS. Aucune suite e2e ne parle à Mailpit —
 * `grep -i 'mailpit|sendMail|EmailService'` dans `test/` ne rend rien. La CI
 * pouvait donc rester verte pendant que le courrier se perdait. Ces tests
 * sont le premier filet posé sous ce service.
 */
import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../config/app-config.service';
import { EmailService } from './email.service';

/** Rend la main après avoir vidé TOUTE la file de microtâches en attente. */
const toutesMicrotaches = (): Promise<void> =>
  new Promise((resolve) => {
    setImmediate(resolve);
  });

/** L'objet que `sendMail` reçoit — typer le mock évite d'avoir à caster ses appels. */
interface EnvoiMail {
  from: string;
  to: string;
  subject: string;
  text: string;
}

interface Banc {
  service: EmailService;
  /** Débloque le n-ième envoi (1 = le premier). */
  poser: (rang: number) => void;
  /** Fait ÉCHOUER le n-ième envoi. */
  refuser: (rang: number) => void;
  /** Ce qui s'est produit, dans l'ordre. */
  ordre: string[];
  sendMail: jest.Mock<Promise<unknown>, [EnvoiMail]>;
  close: jest.Mock;
  logger: { info: jest.Mock; error: jest.Mock };
}

jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => (globalThis as { __transport?: unknown }).__transport),
}));

function banc(): Banc {
  const ordre: string[] = [];
  const verrous: { resoudre: () => void; rejeter: () => void }[] = [];
  const sendMail: jest.Mock<Promise<unknown>, [EnvoiMail]> = jest.fn(
    (_envoi: EnvoiMail) =>
      new Promise<unknown>((resolve, reject) => {
        verrous.push({
          resoudre: () => {
            resolve(undefined);
          },
          rejeter: () => {
            reject(new Error('SMTP indisponible'));
          },
        });
      }),
  );
  const close = jest.fn(() => {
    ordre.push('transporteur fermé');
  });
  (globalThis as { __transport?: unknown }).__transport = { sendMail, close };

  const logger = { info: jest.fn(), error: jest.fn() };
  const config = {
    smtpHost: 'localhost',
    smtpPort: 1025,
    emailFrom: 'carlys@example.test',
    publicAppUrl: 'https://carlys.test',
    emailVerificationTtlHours: 24,
    passwordResetTtlMinutes: 60,
  };

  return {
    service: new EmailService(
      config as unknown as AppConfigService,
      logger as unknown as PinoLogger,
    ),
    poser: (rang) => {
      ordre.push(`envoi ${rang}`);
      verrous[rang - 1]?.resoudre();
    },
    refuser: (rang) => {
      ordre.push(`refus ${rang}`);
      verrous[rang - 1]?.rejeter();
    },
    ordre,
    sendMail,
    close,
    logger,
  };
}

describe('EmailService', () => {
  it('sendEmailVerification ne bloque PAS l’appelant', () => {
    const b = banc();

    b.service.sendEmailVerification('membre@carlys.test', 'jeton-abc');

    // L'envoi est parti, et la méthode a déjà rendu la main : rien n'est posé.
    expect(b.sendMail).toHaveBeenCalledTimes(1);
    expect(b.ordre).toEqual([]);
    const envoi = b.sendMail.mock.calls[0]?.[0];
    expect(envoi?.to).toBe('membre@carlys.test');
    expect(envoi?.text).toContain('https://carlys.test/verify-email?token=jeton-abc');
  });

  it('sendPasswordReset porte le lien et le délai d’expiration', () => {
    const b = banc();

    b.service.sendPasswordReset('membre@carlys.test', 'jeton-xyz');

    const envoi = b.sendMail.mock.calls[0]?.[0];
    expect(envoi?.subject).toContain('réinitialisation');
    expect(envoi?.text).toContain('https://carlys.test/reset-password?token=jeton-xyz');
    expect(envoi?.text).toContain('60 minutes');
  });

  it('l’arrêt ATTEND l’envoi en vol, puis ferme le transporteur', async () => {
    // LE DÉFAUT. Sans l'attente, `transporter.close()` s'exécutait pendant
    // que l'e-mail était encore en vol : la personne recevait son 200 et
    // jamais son lien. L'ORDRE est ce qui le prouve — « transporteur fermé »
    // ne doit jamais précéder « envoi 1 ».
    const b = banc();
    b.service.sendEmailVerification('membre@carlys.test', 'jeton-abc');

    const arret = b.service.onModuleDestroy().then(() => b.ordre.push('arrêt'));

    // On draine TOUTE la file de microtâches sans débloquer l'envoi : si
    // l'arrêt ne l'attendait pas, il aurait déjà fermé et rendu la main.
    await toutesMicrotaches();
    expect(b.ordre).toEqual([]);
    expect(b.close).not.toHaveBeenCalled();

    b.poser(1);
    await arret;

    expect(b.ordre).toEqual(['envoi 1', 'transporteur fermé', 'arrêt']);
  });

  it('un envoi REFUSÉ est compté, journalisé, et ne fait pas échouer l’arrêt', async () => {
    // L'autre moitié du contrat : un SMTP en panne ne doit pas empêcher le
    // conteneur de s'arrêter. Mais `flush` ne doit pas PRÉTENDRE que le
    // courrier est parti — d'où `echouees`, qui distingue « c'était encore
    // en vol » de « le serveur a refusé ».
    const b = banc();
    b.service.sendPasswordReset('membre@carlys.test', 'jeton-xyz');

    const drainage = b.service.flush();
    await toutesMicrotaches();
    b.refuser(1);

    await expect(drainage).resolves.toEqual({ abandonnees: 0, echouees: 1 });
    expect(b.logger.error).toHaveBeenCalled();
    await expect(b.service.onModuleDestroy()).resolves.toBeUndefined();
  });
});
