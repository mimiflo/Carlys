import { Injectable } from '@nestjs/common';
import * as argon2 from 'argon2';
import { AppConfigService } from '../../../config/app-config.service';

/**
 * Hachage des mots de passe en Argon2id, paramètres configurables par
 * environnement (défauts OWASP). Le mot de passe en clair ne sort jamais
 * de ce service et n'est jamais journalisé.
 */
@Injectable()
export class PasswordService {
  constructor(private readonly config: AppConfigService) {}

  hash(password: string): Promise<string> {
    const options = this.config.argon2Options;
    return argon2.hash(password, {
      type: argon2.argon2id,
      memoryCost: options.memoryCost,
      timeCost: options.timeCost,
      parallelism: options.parallelism,
    });
  }

  async verify(hash: string, password: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, password);
    } catch {
      // Hash corrompu ou format inattendu : on refuse sans lever.
      return false;
    }
  }
}
