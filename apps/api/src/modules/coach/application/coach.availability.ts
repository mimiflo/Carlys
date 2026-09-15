import { ForbiddenException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { EntitlementsService } from '../../subscriptions/application/entitlements.service';

const REQUIRED_ENTITLEMENT = 'ai_coaching';

/**
 * La PORTE du coach : le service ne s'ouvre ni sans configuration, ni sans
 * droit.
 *
 * Extraite de `CoachService`, qui orchestre un tour de conversation et n'a
 * pas à porter en plus la règle d'accès — deux dépendances (`config`,
 * `entitlements`) ne servaient d'ailleurs qu'à elle. Le découpage n'est pas
 * cosmétique : la règle a sa propre raison de changer (un droit qui se
 * renomme, un interrupteur d'exploitation qui s'ajoute) et n'a rien à voir
 * avec la façon dont un message est envoyé.
 */
@Injectable()
export class CoachAvailability {
  constructor(
    private readonly entitlements: EntitlementsService,
    private readonly config: AppConfigService,
  ) {}

  /**
   * Coupé globalement ou sans clé → 503. Sans droit → 403. Dans les deux cas,
   * AVANT toute dépense de jeton : un refus ne coûte jamais un tour de quota
   * ni un appel au modèle.
   */
  async assertAvailable(userId: string): Promise<void> {
    if (!this.config.coachEnabled || this.config.anthropicApiKey === undefined) {
      throw new ServiceUnavailableException('Le coach est momentanément indisponible.');
    }
    const { entitlements } = await this.entitlements.entitlementsFor(userId);
    const granted = entitlements.some(
      (entitlement) => entitlement.key === REQUIRED_ENTITLEMENT && entitlement.isActive,
    );
    if (!granted) {
      throw new ForbiddenException('Le coach est réservé aux abonnés.');
    }
  }
}
