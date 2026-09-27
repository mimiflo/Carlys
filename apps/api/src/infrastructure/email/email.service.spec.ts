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
import { createTransport } from 'nodemailer';
import { type RedisService } from '../cache/redis.service';
import { EmailService, LINKS_PER_ADDRESS } from './email.service';

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
  logger: { info: jest.Mock; error: jest.Mock; warn: jest.Mock };
  /** Les compteurs du plafond par adresse, et un interrupteur de panne. */
  compteurs: Map<string, number>;
  redisEnPanne: (panne: boolean) => void;
}

/**
 * Un Redis réduit à ce que le plafond par adresse emploie — `MULTI`,
 * `SET … NX` puis `INCR` —, avec leur sens réel : la première écriture
 * pose le compteur, les suivantes l'incrémentent.
 */
function fauxRedis(): {
  redis: RedisService;
  compteurs: Map<string, number>;
  panne: { active: boolean };
} {
  const compteurs = new Map<string, number>();
  const panne = { active: false };
  const multi = () => {
    const operations: Array<() => [null, unknown]> = [];
    const chaine = {
      set: (cle: string, valeur: number) => {
        operations.push(() => {
          if (!compteurs.has(cle)) {
            compteurs.set(cle, valeur);
          }
          return [null, 'OK'];
        });
        return chaine;
      },
      incr: (cle: string) => {
        operations.push(() => {
          const suivant = (compteurs.get(cle) ?? 0) + 1;
          compteurs.set(cle, suivant);
          return [null, suivant];
        });
        return chaine;
      },
      exec: () =>
        panne.active
          ? Promise.reject(new Error('Redis injoignable'))
          : Promise.resolve(operations.map((operation) => operation())),
    };
    return chaine;
  };
  return {
    redis: { getClient: () => ({ multi }) } as unknown as RedisService,
    compteurs,
    panne,
  };
}

jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => (globalThis as { __transport?: unknown }).__transport),
}));

function banc(surcharges: Record<string, unknown> = {}): Banc {
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

  const logger = { info: jest.fn(), error: jest.fn(), warn: jest.fn() };
  const { redis, compteurs, panne } = fauxRedis();
  const config = {
    smtpHost: 'localhost',
    smtpPort: 1025,
    smtpUser: '',
    smtpPassword: '',
    smtpSecure: false,
    emailFrom: 'carlys@example.test',
    publicAppUrl: 'https://carlys.test',
    emailVerificationTtlHours: 24,
    passwordResetTtlMinutes: 60,
    logFingerprintKey: Buffer.from('cle-de-test'),
    ...surcharges,
  };

  return {
    service: new EmailService(
      config as unknown as AppConfigService,
      redis,
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
    compteurs,
    redisEnPanne: (etat) => {
      panne.active = etat;
    },
  };
}

describe('EmailService — authentification du relais', () => {
  /**
   * Le verrou de production qui manquait : le transport se construisait sans
   * bloc `auth`, et AUCUN relais commercial (SES, SendGrid, Mailgun,
   * Postmark, OVH) n'accepte un envoi non authentifié. Sans e-mail sortant,
   * la vérification d'adresse et la réinitialisation de mot de passe ne
   * fonctionnent pas, et l'inscription paraît cassée sans qu'aucun journal ne
   * le dise.
   */
  const transportCree = (): Record<string, unknown> => {
    const dernier = jest.mocked(createTransport).mock.calls.at(-1);
    expect(dernier).toBeDefined();
    return dernier![0] as unknown as Record<string, unknown>;
  };

  it('sans identifiant, AUCUN bloc auth : Mailpit refuserait une authentification vide', () => {
    banc();
    expect(transportCree()).not.toHaveProperty('auth');
  });

  it('avec un identifiant, le bloc auth part au relais', () => {
    banc({ smtpUser: 'apikey', smtpPassword: 'secret-du-relais' });
    expect(transportCree().auth).toEqual({
      user: 'apikey',
      pass: 'secret-du-relais',
    });
  });

  it('`secure` suit la configuration, et vaut faux par défaut (STARTTLS sur 587)', () => {
    banc();
    expect(transportCree().secure).toBe(false);

    banc({ smtpSecure: true }); // port 465, TLS dès la connexion
    expect(transportCree().secure).toBe(true);
  });
});

describe('EmailService', () => {
  it('sendEmailVerification ne bloque PAS l’appelant', async () => {
    const b = banc();

    b.service.sendEmailVerification('membre@carlys.test', 'jeton-abc');

    // La méthode a déjà rendu la main : rien n'est posé. L'envoi part dès
    // que le plafond par adresse a répondu.
    expect(b.ordre).toEqual([]);
    await toutesMicrotaches();
    expect(b.sendMail).toHaveBeenCalledTimes(1);
    const envoi = b.sendMail.mock.calls[0]?.[0];
    expect(envoi?.to).toBe('membre@carlys.test');
    expect(envoi?.text).toContain('https://carlys.test/verify-email?token=jeton-abc');
  });

  it('sendPasswordReset porte le lien et le délai d’expiration', async () => {
    const b = banc();

    b.service.sendPasswordReset('membre@carlys.test', 'jeton-xyz');
    await toutesMicrotaches();

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

describe('EmailService — aucune adresse en clair dans les journaux', () => {
  const ADRESSE = 'Membre.Vise@carlys.test';

  it('un envoi réussi journalise une EMPREINTE du destinataire, jamais l’adresse', async () => {
    const b = banc();
    b.sendMail.mockImplementationOnce(() => Promise.resolve({}));
    b.service.sendEmailVerification(ADRESSE, 'jeton-abc');
    await b.service.flush();

    expect(b.logger.info).toHaveBeenCalledTimes(1);
    const journal = JSON.stringify(b.logger.info.mock.calls);
    expect(journal.toLowerCase()).not.toContain('membre.vise@carlys.test');
    expect((b.logger.info.mock.calls as unknown[][])[0]?.[0]).toMatchObject({
      recipient: expect.stringMatching(/^[0-9a-f]{12}$/) as unknown,
    });
  });

  it('un refus SMTP qui CITE l’adresse est journalisé sans elle', async () => {
    const b = banc();
    const refus = Object.assign(
      new Error(`Can't send mail - all recipients were rejected: 550 <${ADRESSE}>: rejected`),
      { rejected: [ADRESSE], responseCode: 550, command: 'RCPT TO' },
    );
    b.sendMail.mockImplementationOnce(() => Promise.reject(refus));
    b.service.sendPasswordReset(ADRESSE, 'jeton-xyz');
    await b.service.flush();

    expect(b.logger.error).toHaveBeenCalledTimes(1);
    const journal = JSON.stringify(b.logger.error.mock.calls);
    expect(journal.toLowerCase()).not.toContain('membre.vise@carlys.test');
    expect((b.logger.error.mock.calls as unknown[][])[0]?.[0]).toMatchObject({
      smtpError: { responseCode: 550, command: 'RCPT TO' },
    });
  });
});

describe('EmailService — plafond de liens par ADRESSE', () => {
  /**
   * Les cadences par compte ne voient pas la rotation des comptes :
   * « s'inscrire avec l'adresse d'une victime, supprimer le compte », en
   * boucle, repartait chaque fois d'une cadence neuve — un courrier par tour.
   */
  const envoyerTous = async (b: Banc, n: number, adresse: string): Promise<void> => {
    b.sendMail.mockImplementation(() => Promise.resolve({}));
    for (let i = 0; i < n; i += 1) {
      b.service.sendEmailVerification(adresse, `jeton-${i}`);
    }
    await b.service.flush();
  };

  it(`au-delà de ${LINKS_PER_ADDRESS} liens vers une même adresse, plus rien ne part`, async () => {
    const b = banc();
    await envoyerTous(b, LINKS_PER_ADDRESS + 3, 'Victime@Carlys.test');

    expect(b.sendMail).toHaveBeenCalledTimes(LINKS_PER_ADDRESS);
    expect(b.logger.warn).toHaveBeenCalledTimes(3);
    // Compté par empreinte à clé, jamais par l'adresse en clair.
    expect([...b.compteurs.keys()].join()).not.toContain('victime');
  });

  it('le plafond est PAR adresse et PAR sorte de lien', async () => {
    const b = banc();
    await envoyerTous(b, LINKS_PER_ADDRESS, 'une@carlys.test');
    b.service.sendEmailVerification('autre@carlys.test', 'jeton-autre');
    b.service.sendPasswordReset('une@carlys.test', 'jeton-reinit');
    await b.service.flush();

    expect(b.sendMail).toHaveBeenCalledTimes(LINKS_PER_ADDRESS + 2);
  });

  it('Redis injoignable : le lien PART quand même, et c’est journalisé', async () => {
    const b = banc();
    b.redisEnPanne(true);
    await envoyerTous(b, 1, 'membre@carlys.test');

    expect(b.sendMail).toHaveBeenCalledTimes(1);
    expect(b.logger.warn).toHaveBeenCalledTimes(1);
  });
});
