import { Injectable, type OnModuleDestroy } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { createTransport, type Transporter } from 'nodemailer';
import { type DrainageResult, TravauxEnVol } from '../../common/async/travaux-en-vol';
import { logFingerprint, withoutEmails } from '../../common/utilities/log-privacy';
import { AppConfigService } from '../../config/app-config.service';
import { RedisService } from '../cache/redis.service';

/**
 * Liens envoyés au plus à une même ADRESSE par fenêtre, tous comptes
 * confondus. Les cadences par compte (vérification : cinq par 24 h ;
 * réinitialisation : cinq par validité d'un lien) ne suffisaient pas : un
 * compte supprimé libère aussitôt son adresse, et « s'inscrire avec
 * l'adresse d'une victime, puis supprimer le compte », en boucle, repartait
 * chaque fois d'une cadence neuve — un courrier Carlys par tour, borné par
 * la seule limite par IP (mesuré : 8 tours, 8 courriers). Même plafond et
 * même fenêtre que la cadence par compte : il ne mord jamais sur l'usage
 * d'un seul compte, seulement sur la rotation des comptes.
 */
export const LINKS_PER_ADDRESS = 5;
const VERIFICATION_WINDOW_SECONDS = 24 * 3_600;

type LinkKind = 'verification' | 'reset';

/**
 * Envoi d'e-mails transactionnels (Mailpit en développement).
 *
 * L'envoi n'est JAMAIS bloquant pour la requête : les méthodes retournent
 * immédiatement et les échecs sont journalisés. Le passage par une file
 * BullMQ est prévu avec le module notifications.
 *
 * CE QUI A ÉTÉ CORRIGÉ. La promesse de `sendMail` était simplement
 * abandonnée (`void … .then().catch()`), et `onModuleDestroy` fermait le
 * transporteur sans rien attendre — le jumeau exact du défaut corrigé dans
 * `AuditService`, avec une conséquence plus visible pour la personne
 * concernée. À chaque déploiement, une inscription ou une demande de
 * réinitialisation servie dans la seconde qui précède l'arrêt voyait son
 * e-mail partir en vol ; le transporteur se fermait, le processus mourait.
 * L'utilisateur recevait un 200, puis attendait un lien de vérification
 * d'adresse ou de mot de passe qui n'arrivait jamais — sans rien à l'écran
 * pour le lui dire, et sans qu'aucun test ne puisse le voir, puisque aucune
 * suite ne parle à Mailpit.
 *
 * Le registre des envois en vol est celui de `common/async/travaux-en-vol.ts`,
 * partagé avec l'audit : c'est le même raisonnement, y compris sur la BORNE
 * du drainage, et il n'a pas à exister en deux exemplaires.
 */
@Injectable()
export class EmailService implements OnModuleDestroy {
  private readonly transporter: Transporter;
  private readonly enVol: TravauxEnVol;

  constructor(
    private readonly config: AppConfigService,
    private readonly redis: RedisService,
    @InjectPinoLogger(EmailService.name)
    private readonly logger: PinoLogger,
  ) {
    // Le bloc `auth` n'est passé que si un identifiant est fourni : Mailpit,
    // en développement, n'authentifie rien, et nodemailer tenterait sinon
    // une authentification vide qu'il refuserait. Sans ce bloc, AUCUN relais
    // commercial n'acceptait l'envoi — c'était le verrou qui rendait la
    // vérification d'adresse et la réinitialisation de mot de passe muettes
    // en production, sans qu'aucun journal ne le dise.
    const user = config.smtpUser;
    this.transporter = createTransport({
      host: config.smtpHost,
      port: config.smtpPort,
      // `false` ne veut PAS dire « en clair » : c'est STARTTLS, que
      // nodemailer négocie seul sur le port 587. `true` est le TLS implicite
      // du port 465.
      secure: config.smtpSecure,
      ...(user === '' ? {} : { auth: { user, pass: config.smtpPassword } }),
    });
    this.enVol = new TravauxEnVol('e-mail', logger);
  }

  sendEmailVerification(to: string, token: string): void {
    const url = `${this.config.publicAppUrl}/verify-email?token=${token}`;
    this.send(
      'verification',
      to,
      'Carlys : confirmez votre adresse e-mail',
      [
        'Bienvenue sur Carlys !',
        '',
        'Confirmez votre adresse e-mail avec ce lien :',
        url,
        '',
        `Ce lien expire dans ${this.config.emailVerificationTtlHours} heures.`,
        "Si vous n'êtes pas à l'origine de cette inscription, ignorez cet e-mail.",
      ].join('\n'),
    );
  }

  sendPasswordReset(to: string, token: string): void {
    const url = `${this.config.publicAppUrl}/reset-password?token=${token}`;
    this.send(
      'reset',
      to,
      'Carlys : réinitialisation de votre mot de passe',
      [
        'Une réinitialisation de mot de passe a été demandée pour votre compte.',
        '',
        'Choisissez un nouveau mot de passe avec ce lien :',
        url,
        '',
        `Ce lien expire dans ${this.config.passwordResetTtlMinutes} minutes.`,
        "Si vous n'êtes pas à l'origine de cette demande, ignorez cet e-mail : votre mot de passe reste inchangé.",
      ].join('\n'),
    );
  }

  /**
   * Attend les envois en vol, et rend ce qu'il en est.
   *
   * `echouees` non nul veut dire que le serveur SMTP a refusé : le courrier
   * n'est pas parti, et l'attendre plus longtemps n'y changerait rien.
   */
  flush(): Promise<DrainageResult> {
    return this.enVol.drainer();
  }

  /**
   * Arrêt propre. L'ordre compte : on DRAINE d'abord, on ferme ensuite.
   * L'inverse — fermer le transporteur puis partir — est ce qui perdait les
   * e-mails de vérification et de réinitialisation à chaque déploiement.
   */
  async onModuleDestroy(): Promise<void> {
    await this.flush();
    this.transporter.close();
  }

  /**
   * Le destinataire n'est JAMAIS journalisé en clair : son empreinte
   * (`recipient`) suffit à corréler les lignes. L'erreur SMTP non plus n'est
   * pas journalisée telle quelle — l'objet de nodemailer porte `rejected`,
   * `envelope` et une réponse qui citent l'adresse ; on n'en garde que le
   * code et le message, adresses retirées.
   */
  private send(kind: LinkKind, to: string, subject: string, text: string): void {
    const recipient = logFingerprint(to.trim().toLowerCase(), this.config.logFingerprintKey);
    this.enVol.suivre(
      this.deliver(kind, recipient, { from: this.config.emailFrom, to, subject, text }),
      {
        succes: () => undefined, // journalisé par `deliver`, qui sait s'il est parti
        echec: (erreur) => {
          this.logger.error(
            { smtpError: describeSmtpError(erreur), recipient, subject },
            "Échec d'envoi d'e-mail",
          );
        },
      },
    );
  }

  private async deliver(
    kind: LinkKind,
    recipient: string,
    mail: { from: string; to: string; subject: string; text: string },
  ): Promise<void> {
    if (!(await this.withinAddressQuota(kind, recipient))) {
      // Rien ne change pour l'appelant ni dans la réponse HTTP : pas d'oracle.
      this.logger.warn(
        { recipient, subject: mail.subject },
        'E-mail non envoyé : plafond de liens par adresse atteint',
      );
      return;
    }
    await this.transporter.sendMail(mail);
    this.logger.info({ recipient, subject: mail.subject }, 'E-mail envoyé');
  }

  /**
   * Compte cet envoi pour l'adresse (par son empreinte à clé, jamais en
   * clair), et dit s'il reste sous [LINKS_PER_ADDRESS]. La fenêtre part du
   * premier envoi (`SET NX EX`) et le compte est atomique (`MULTI`) : des
   * envois simultanés ne lisent pas le même décompte.
   *
   * Redis indisponible : l'envoi PART, et c'est journalisé — comme le
   * verrouillage des connexions, la disponibilité prime ; les cadences par
   * compte, en base, restent actives.
   */
  private async withinAddressQuota(kind: LinkKind, recipient: string): Promise<boolean> {
    const key = `mail:${kind}:${recipient}`;
    const windowSeconds =
      kind === 'reset' ? this.config.passwordResetTtlMinutes * 60 : VERIFICATION_WINDOW_SECONDS;
    try {
      const results = await this.redis
        .getClient()
        .multi()
        .set(key, 0, 'EX', windowSeconds, 'NX')
        .incr(key)
        .exec();
      const incr = results?.[1];
      if (incr === undefined || incr[0] !== null) {
        throw incr?.[0] ?? new Error('MULTI sans résultat');
      }
      return Number(incr[1]) <= LINKS_PER_ADDRESS;
    } catch (error) {
      this.logger.warn({ err: error, recipient }, 'Plafond par adresse illisible — envoi permis');
      return true;
    }
  }
}

/** Ce qu'une erreur SMTP peut dire au journal sans nommer personne. */
function describeSmtpError(erreur: unknown): Record<string, unknown> {
  if (!(erreur instanceof Error)) {
    return { message: withoutEmails(String(erreur)) };
  }
  const { code, responseCode, command } = erreur as {
    code?: unknown;
    responseCode?: unknown;
    command?: unknown;
  };
  return { name: erreur.name, message: withoutEmails(erreur.message), code, responseCode, command };
}
