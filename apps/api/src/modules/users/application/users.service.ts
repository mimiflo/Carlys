import { type AuthUser, type TrainingProfile } from '@carlys/api-contracts';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  type ActivityLevel,
  type BiologicalSex,
  type CarlysProfile,
  type MentorStyle,
  type NutritionGoal,
  type TrainingExperience,
  type TrainingGoal,
} from '@prisma/client';
import { presentUser } from '../../auth/application/user.presenter';
import { UsersRepository } from '../infrastructure/users.repository';

export interface UpdateProfileInput {
  displayName?: string;
  locale?: string;
  timezone?: string;
  /** Identité Carlys — pas un niveau, modifiable à tout moment. */
  carlysProfile?: CarlysProfile;
  /** Voix du Mentor — un axe indépendant du profil, modifiable à tout moment. */
  mentorStyle?: MentorStyle;
  /** Objectif d'entraînement — distinct de l'objectif nutritionnel. */
  trainingGoal?: TrainingGoal;
  trainingExperience?: TrainingExperience;
  weeklySessionsTarget?: number;
  sessionMinutesTarget?: number;
  /** Remplacement COMPLET de la liste ; slug inconnu refusé en 400. */
  equipmentSlugs?: string[];
  sex?: BiologicalSex;
  birthDate?: Date;
  heightCm?: number;
  activityLevel?: ActivityLevel;
  nutritionGoal?: NutritionGoal;
}

@Injectable()
export class UsersService {
  constructor(private readonly users: UsersRepository) {}

  async me(userId: string): Promise<AuthUser> {
    const user = await this.users.findActiveById(userId);
    if (user === null) {
      throw new NotFoundException('Compte introuvable.');
    }
    return presentUser(user);
  }

  async updateProfile(userId: string, data: UpdateProfileInput): Promise<AuthUser> {
    const user = await this.users.findActiveById(userId);
    if (user === null) {
      throw new NotFoundException('Compte introuvable.');
    }
    // La date de naissance est bornée par `UpdateProfileDto`, à partir de
    // `birthDateRange` du contrat. Elle l'était AUSSI ici, avec un maximum de
    // 120 ans recopié — deux règles pour un seul fait, dont celle-ci n'était
    // couverte par aucun test unitaire (ce module n'a pas de `.spec.ts`).
    // Le matériel se VALIDE avant toute écriture : un slug inconnu doit
    // rendre 400 sans avoir touché ni les scalaires ni la liste.
    const equipmentIds =
      data.equipmentSlugs === undefined
        ? undefined
        : await this.resolveEquipment(data.equipmentSlugs);
    const profileData = {
      ...(data.displayName === undefined ? {} : { displayName: data.displayName.trim() }),
      ...(data.locale === undefined ? {} : { locale: data.locale }),
      ...(data.timezone === undefined ? {} : { timezone: data.timezone }),
      ...(data.carlysProfile === undefined ? {} : { carlysProfile: data.carlysProfile }),
      ...(data.mentorStyle === undefined ? {} : { mentorStyle: data.mentorStyle }),
      ...(data.trainingGoal === undefined ? {} : { trainingGoal: data.trainingGoal }),
      ...(data.trainingExperience === undefined
        ? {}
        : { trainingExperience: data.trainingExperience }),
      ...(data.weeklySessionsTarget === undefined
        ? {}
        : { weeklySessionsTarget: data.weeklySessionsTarget }),
      ...(data.sessionMinutesTarget === undefined
        ? {}
        : { sessionMinutesTarget: data.sessionMinutesTarget }),
      ...(data.sex === undefined ? {} : { sex: data.sex }),
      ...(data.birthDate === undefined ? {} : { birthDate: data.birthDate }),
      // Rangée ARRONDIE au dixième : la validation juge la valeur (175.1 et
      // son artefact flottant 175.10000000000002 sont la même taille) — la
      // base ne doit porter que la forme canonique.
      ...(data.heightCm === undefined ? {} : { heightCm: Math.round(data.heightCm * 10) / 10 }),
      ...(data.activityLevel === undefined ? {} : { activityLevel: data.activityLevel }),
      ...(data.nutritionGoal === undefined ? {} : { nutritionGoal: data.nutritionGoal }),
    };
    const updated =
      equipmentIds === undefined
        ? await this.users.updateProfile(userId, profileData)
        : await this.users.updateProfileAndEquipment(userId, profileData, equipmentIds);
    return presentUser(updated);
  }

  /** Les entrées de génération de programme, en UN instantané cohérent. */
  async training(userId: string): Promise<TrainingProfile> {
    const { user, equipmentSlugs } = await this.users.trainingSnapshot(userId);
    if (user === null) {
      throw new NotFoundException('Compte introuvable.');
    }
    return {
      trainingGoal: user.profile?.trainingGoal ?? null,
      trainingExperience: user.profile?.trainingExperience ?? null,
      weeklySessionsTarget: user.profile?.weeklySessionsTarget ?? null,
      sessionMinutesTarget: user.profile?.sessionMinutesTarget ?? null,
      equipmentSlugs,
    };
  }

  /** Slugs → identifiants de la taxonomie ; tout inconnu est NOMMÉ en 400. */
  private async resolveEquipment(slugs: string[]): Promise<string[]> {
    const uniques = [...new Set(slugs)];
    const found = await this.users.findEquipmentBySlugs(uniques);
    const knownSlugs = new Set(found.map((equipment) => equipment.slug));
    const unknown = uniques.filter((slug) => !knownSlugs.has(slug));
    if (unknown.length > 0) {
      throw new BadRequestException(`Matériel inconnu : ${unknown.join(', ')}.`);
    }
    return found.map((equipment) => equipment.id);
  }
}
