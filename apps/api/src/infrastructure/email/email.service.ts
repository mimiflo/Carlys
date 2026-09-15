import { Injectable, type OnModuleDestroy } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { createTransport, type Transporter } from 'nodemailer';
import { type DrainageResult, TravauxEnVol } from '../../common/async/travaux-en-vol';
import { AppConfigService } from '../../config/app-config.service';

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
    @InjectPinoLogger(EmailService.name)
    private readonly logger: PinoLogger,
  ) {
    this.transporter = createTransport({
      host: config.smtpHost,
      port: config.smtpPort,
      secure: false,
    });
    this.enVol = new TravauxEnVol('e-mail', logger);
  }

  sendEmailVerification(to: string, token: string): void {
    const url = `${this.config.publicAppUrl}/verify-email?token=${token}`;
    this.send(
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

  private send(to: string, subject: string, text: string): void {
    this.enVol.suivre(
      this.transporter.sendMail({ from: this.config.emailFrom, to, subject, text }),
      {
        succes: () => {
          this.logger.info({ to, subject }, 'E-mail envoyé');
        },
        echec: (erreur) => {
          this.logger.error({ err: erreur, to, subject }, "Échec d'envoi d'e-mail");
        },
      },
    );
  }
}
