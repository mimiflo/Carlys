import { Injectable, type OnModuleDestroy } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { createTransport, type Transporter } from 'nodemailer';
import { AppConfigService } from '../../config/app-config.service';

/**
 * Envoi d'e-mails transactionnels (Mailpit en développement).
 *
 * L'envoi n'est JAMAIS bloquant pour la requête : les méthodes retournent
 * immédiatement et les échecs sont journalisés. Le passage par une file
 * BullMQ est prévu avec le module notifications.
 */
@Injectable()
export class EmailService implements OnModuleDestroy {
  private readonly transporter: Transporter;

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
  }

  sendEmailVerification(to: string, token: string): void {
    const url = `${this.config.publicAppUrl}/verify-email?token=${token}`;
    this.send(
      to,
      'Confirmez votre adresse e-mail — Carlys',
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
      'Réinitialisation de votre mot de passe — Carlys',
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

  onModuleDestroy(): void {
    this.transporter.close();
  }

  private send(to: string, subject: string, text: string): void {
    void this.transporter
      .sendMail({ from: this.config.emailFrom, to, subject, text })
      .then(() => {
        this.logger.info({ to, subject }, 'E-mail envoyé');
      })
      .catch((error: unknown) => {
        this.logger.error({ err: error, to, subject }, "Échec d'envoi d'e-mail");
      });
  }
}
