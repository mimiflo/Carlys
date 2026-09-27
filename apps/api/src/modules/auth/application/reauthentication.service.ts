import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { LockoutService, lockoutMessage } from './lockout.service';
import { PasswordService } from './password.service';

/**
 * Compteur de verrouillage des RE-authentifications d'un compte connecté.
 *
 * Distinct de celui de la connexion (indexé sur l'e-mail) : sinon, qui tient
 * une session volée pourrait, à coups de mauvais mots de passe, verrouiller
 * la CONNEXION du propriétaire légitime.
 */
export function reauthLockoutKey(userId: string): string {
  return `reauth:${userId}`;
}

/**
 * Vérifie le mot de passe d'une personne DÉJÀ connectée, avant un geste
 * sensible : changer de mot de passe, supprimer le compte.
 *
 * POURQUOI UN VERROUILLAGE ICI AUSSI. La connexion bloque après
 * `AUTH_MAX_LOGIN_ATTEMPTS` échecs par compte ; ces deux routes ne bloquaient
 * rien. Elles faisaient donc un oracle de mot de passe à 100 essais par minute
 * et par adresse IP (la limite globale), sans aucun plafond par compte — il
 * suffisait de multiplier les IP. Qui tenait un jeton volé pouvait ainsi
 * retrouver le mot de passe, et le premier essai juste, sur
 * `change-password`, révoquait toutes les autres sessions : le propriétaire
 * était dehors. Mesuré avant correctif : 30 essais faux en 1,1 s, aucun 429,
 * et le 31e, juste, passait.
 *
 * Même politique que la connexion (seuil et durée partagés), compteur à part
 * ([reauthLockoutKey]). Un succès remet le compteur à zéro.
 *
 * L'essai est RÉSERVÉ avant la vérification ([LockoutService.reserveAttempt]),
 * pas compté après : sinon une rafale d'essais simultanés, un par adresse IP,
 * passait tout entière avant que le premier échec soit compté (mesuré : 25
 * vérifications sur 30 essais parallèles, pour un seuil de 5).
 */
@Injectable()
export class ReauthenticationService {
  constructor(
    private readonly passwords: PasswordService,
    private readonly lockout: LockoutService,
  ) {}

  /**
   * `true` si `candidate` est le mot de passe du compte. Lève 429 si le
   * compte est verrouillé — AVANT toute vérification Argon2, pour qu'un
   * essai de plus ne dise rien, même juste.
   */
  async verify(userId: string, passwordHash: string, candidate: string): Promise<boolean> {
    const key = reauthLockoutKey(userId);
    const lock = await this.lockout.reserveAttempt(key);
    if (lock.locked) {
      throw new HttpException(lockoutMessage(lock), HttpStatus.TOO_MANY_REQUESTS);
    }
    const valid = await this.passwords.verify(passwordHash, candidate);
    if (valid) {
      await this.lockout.reset(key);
    }
    return valid;
  }
}
