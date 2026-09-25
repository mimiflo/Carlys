import { type MealEntry as MealEntryContract } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  compositionChange,
  computedFieldsSent,
  creationPlan,
  patchConflict,
} from '../domain/meal-write-rules';
import {
  ComponentIdTakenError,
  MealsRepository,
  type MealWithComponents,
} from '../infrastructure/meals.repository';
import { type FoodCatalog, MealComposer } from './meal-composer';
import { MEAL_NOT_FOUND, planCorrection } from './meal-correction';
import { MealPhotoObjects } from './meal-photo-objects';
import { presentMeal } from './meal-presenter';
import {
  assertPairedQuantity,
  computedColumns,
  type MealDraft,
  type MealPatch,
} from './meal-writes';

/**
 * L'amplitude maximale d'une demande de journal.
 *
 * Un an couvre largement ce que les écrans demandent — le jour courant, la
 * semaine, au plus un mois pour une courbe — tout en refusant la demande
 * dégénérée : deux dates éloignées d'une décennie, servies en une fois. Le
 * plafond de LIGNES (`MealsRepository.HARD_LIMIT`) ferme l'autre moitié de la
 * porte : une année chargée reste bornée en volume.
 */
const MAX_RANGE_DAYS = 366;
const MAX_RANGE_MS = MAX_RANGE_DAYS * 24 * 3_600_000;

/** Une ligne d'aliment porte l'identifiant d'une ligne d'un autre repas. */
const COMPONENT_ID_TAKEN =
  'Un identifiant de ligne d’aliment est déjà pris par un autre repas : chaque ligne ajoutée reçoit un UUID neuf.';

const NO_FOODS: FoodCatalog = new Map();

/**
 * Journal alimentaire — la moitié RÉELLE du « consommé / objectif ».
 *
 * Mêmes règles que les séances : identifiant généré sur l'appareil (création
 * idempotente, rejouable), suppression douce idempotente, et des INSTANTS
 * UTC — le découpage en journées appartient au client, qui connaît son
 * fuseau ; le serveur ne devine jamais où commence « aujourd'hui ».
 *
 * Un repas est saisi à la main OU composé d'aliments de la base : les règles
 * qui départagent les deux vivent dans `domain/meal-write-rules.ts`, le
 * calcul dans `MealComposer`.
 */
@Injectable()
export class MealsService {
  constructor(
    private readonly meals: MealsRepository,
    private readonly composer: MealComposer,
    private readonly photoObjects: MealPhotoObjects,
  ) {}

  /** Création idempotente : rejouer la même écriture rend la même entrée. */
  async add(userId: string, draft: MealDraft): Promise<MealEntryContract> {
    const plan = creationPlan(draft);
    if (plan.kind === 'refused') {
      throw new BadRequestException(plan.message);
    }
    // Un REJEU rend l'entrée déjà écrite, sans recomposer : la file de
    // synchronisation peut renvoyer un repas composé des jours plus tard, et
    // un aliment retiré entre-temps par une nouvelle version de la table
    // ferait échouer en 400 un repas pourtant bien enregistré.
    const existing = await this.meals.findById(draft.id);
    if (existing !== null) {
      return this.replayed(existing, userId);
    }
    const base = {
      id: draft.id,
      userId,
      name: draft.name,
      moment: draft.moment ?? null,
      eatenAt: draft.eatenAt,
    };
    if (plan.kind === 'composed') {
      const composition = await this.composer.compose(plan.items);
      await this.meals.create(
        { ...base, ...computedColumns(composition.totals) },
        composition.rows,
      );
    } else {
      const quantity = draft.quantity ?? null;
      const quantityUnit = draft.quantityUnit ?? null;
      assertPairedQuantity(quantity, quantityUnit);
      await this.meals.create(
        {
          ...base,
          kcal: plan.kcal,
          quantity,
          quantityUnit,
          proteinG: draft.proteinG ?? null,
          carbsG: draft.carbsG ?? null,
          fatG: draft.fatG ?? null,
        },
        [],
      );
    }
    // Relu, et non reconstruit : deux créations simultanées du même id se
    // départagent en base (`create` ignore la seconde), et c'est la première
    // qui fait foi pour les deux.
    return this.replayed(await this.meals.findById(draft.id), userId);
  }

  private replayed(stored: MealWithComponents | null, userId: string): MealEntryContract {
    if (stored === null) {
      // L'écriture a buté sur un identifiant déjà pris, et ce n'est pas
      // celui du repas, introuvable : c'est celui d'une de ses lignes.
      throw new ConflictException(COMPONENT_ID_TAKEN);
    }
    if (stored.userId !== userId) {
      // L'identifiant existe déjà chez QUELQU'UN D'AUTRE : collision réelle.
      throw new ConflictException('Identifiant de repas déjà utilisé.');
    }
    return presentMeal(stored);
  }

  /**
   * Un repas, composants compris. Inconnu, supprimé ou d'autrui : le même
   * 404 — un 403 confirmerait que l'identifiant existe.
   */
  async get(userId: string, id: string): Promise<MealEntryContract> {
    return presentMeal(await this.owned(userId, id));
  }

  /**
   * Repas entre deux instants (bornes du jour local, calculées au client).
   *
   * La plage est BORNÉE, et la requête plafonnée. C'était la seule collection
   * du dépôt sans plafond : toutes les autres portent un `limit` validé
   * (`@Max(MAX_PAGE_SIZE)` pour les séances et les modèles, `@Max(365)` pour
   * les mesures corporelles, `@Max(200)` pour l'audit). Ici, deux dates
   * suffisaient à demander des années de journal en une requête, et le dépôt
   * servait tout. L'écran, lui, ne demande jamais qu'un jour ou une semaine.
   */
  async list(userId: string, from: Date, to: Date): Promise<MealEntryContract[]> {
    if (to.getTime() <= from.getTime()) {
      throw new BadRequestException('La borne haute doit suivre la borne basse.');
    }
    if (to.getTime() - from.getTime() > MAX_RANGE_MS) {
      throw new BadRequestException(
        `La plage demandée dépasse ${MAX_RANGE_DAYS} jours : découpe la demande.`,
      );
    }
    const meals = await this.meals.listBetween(userId, from, to);
    return meals.map(presentMeal);
  }

  /**
   * Correction d'un repas déjà journalisé.
   *
   * On se trompe en tapant — une calorie de trop, le bon plat la veille, une
   * portion mal estimée — et la seule réparation offerte jusqu'ici était de
   * supprimer puis ressaisir : le repas disparaissait du total, puis
   * revenait, sous un AUTRE identifiant. Corriger sur place garde l'entrée,
   * son identifiant et sa place dans le journal.
   *
   * Un champ ABSENT reste tel quel, un champ à `null` efface ce qu'on croyait
   * savoir : corriger les calories ne doit pas emporter les macros. Une
   * nouvelle composition recalcule tout, en gardant l'instantané des lignes
   * qu'elle désigne par leur identifiant ; une composition retirée
   * (`components: []`) laisse le repas avec ses DERNIERS totaux, désormais
   * corrigeables à la main.
   *
   * Tout ce qui dépend de l'état du repas se décide SOUS LE VERROU de sa
   * ligne (`planCorrection`, appelée par `MealsRepository.correct`) : deux
   * corrections simultanées passent l'une après l'autre, et la seconde juge
   * l'état que la première a laissé.
   */
  async update(userId: string, id: string, patch: MealPatch): Promise<MealEntryContract> {
    if (Object.values(patch).every((value) => value === undefined)) {
      throw new BadRequestException('Rien à corriger : donne au moins un champ.');
    }
    const change = compositionChange(patch.components);
    // Des aliments ET des totaux : refusé avant toute lecture, quel que soit le repas.
    const ambiguous = patchConflict(change, computedFieldsSent(patch), false);
    if (ambiguous !== null) {
      throw new BadRequestException(ambiguous);
    }
    // La base d'aliments se lit AVANT le verrou : elle ne change qu'à
    // l'import, et la lire sous verrou tiendrait la ligne du repas pendant
    // un aller-retour de plus.
    const catalog =
      change.kind === 'replace' ? await this.composer.catalogFor(change.items) : NO_FOODS;
    let corrected: MealWithComponents | null;
    try {
      corrected = await this.meals.correct(id, (current) =>
        planCorrection({ userId, current, patch, change, catalog }),
      );
    } catch (error) {
      if (error instanceof ComponentIdTakenError) {
        throw new ConflictException(COMPONENT_ID_TAKEN);
      }
      throw error;
    }
    if (corrected === null) {
      throw new NotFoundException(MEAL_NOT_FOUND);
    }
    return presentMeal(corrected);
  }

  /**
   * Idempotent : supprimer un repas déjà supprimé ou inconnu aboutit.
   *
   * Sa photo part avec lui : la ligne dans la transaction de la suppression
   * douce, puis l'objet du bucket privé. Un échec de ce second temps est
   * journalisé et ne fait pas échouer la suppression, qui a bien eu lieu.
   */
  async remove(userId: string, id: string, requestId?: string): Promise<void> {
    const meal = await this.meals.findById(id);
    if (meal === null || meal.deletedAt !== null) {
      return;
    }
    if (meal.userId !== userId) {
      // Même réponse qu'un 404 : ne pas révéler l'existence d'autrui.
      throw new NotFoundException(MEAL_NOT_FOUND);
    }
    const photoKey = await this.meals.softDelete(id);
    if (photoKey !== null) {
      await this.photoObjects.discard(photoKey, requestId);
    }
  }

  /** Le repas vivant de cette personne, ou un 404 qui ne dit pas pourquoi. */
  private async owned(userId: string, id: string): Promise<MealWithComponents> {
    const stored = await this.meals.findById(id);
    if (stored === null || stored.userId !== userId || stored.deletedAt !== null) {
      throw new NotFoundException(MEAL_NOT_FOUND);
    }
    return stored;
  }
}
