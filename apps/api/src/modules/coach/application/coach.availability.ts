import { ForbiddenException, Injectable } from '@nestjs/common';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
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
   * Coupé globalement ou fournisseur mal réglé → 503, au message LISIBLE
   * (`UserFacingUnavailableException`) : un 503 ordinaire arrivait à l'écran
   * en « Une erreur interne est survenue. ». Sans droit → 403. Dans
   * les deux cas, AVANT toute dépense de jeton : un refus ne coûte jamais un
   * tour de quota ni un appel au modèle.
   */
  async assertAvailable(userId: string): Promise<void> {
    if (!this.config.coachEnabled || !this.providerConfigured()) {
      throw new UserFacingUnavailableException('Le coach est momentanément indisponible.');
    }
    await this.assertEntitled(userId);
  }

  /**
   * Le scan d'assiette : le coach allumé, ses workers, SON modèle de vision,
   * et le même droit que le coach — c'est le même modèle qui travaille.
   */
  async assertVisionAvailable(userId: string): Promise<string> {
    const model = this.config.coachProvider.visionModel;
    if (!this.config.coachEnabled || this.config.coachGateway.workerUrls.length === 0 || !model) {
      throw new UserFacingUnavailableException(
        'Le scan d’assiette est momentanément indisponible.',
      );
    }
    await this.assertEntitled(userId);
    return model;
  }

  private async assertEntitled(userId: string): Promise<void> {
    const { entitlements } = await this.entitlements.entitlementsFor(userId);
    const granted = entitlements.some(
      (entitlement) => entitlement.key === REQUIRED_ENTITLEMENT && entitlement.isActive,
    );
    if (!granted) {
      throw new ForbiddenException('Le coach est réservé aux abonnés.');
    }
  }

  /**
   * Un worker au moins, et son modèle (la clé, elle, manque légitimement à
   * un Ollama interne). Aucun autre fournisseur n'existe.
   */
  private providerConfigured(): boolean {
    return (
      this.config.coachGateway.workerUrls.length > 0 &&
      this.config.coachProvider.model !== undefined
    );
  }
}
