import { type AuthUser } from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import {
  type ActivityLevel,
  type BiologicalSex,
  type CarlysProfile,
  type MentorStyle,
  type NutritionGoal,
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
    const updated = await this.users.updateProfile(userId, {
      ...(data.displayName === undefined ? {} : { displayName: data.displayName.trim() }),
      ...(data.locale === undefined ? {} : { locale: data.locale }),
      ...(data.timezone === undefined ? {} : { timezone: data.timezone }),
      ...(data.carlysProfile === undefined ? {} : { carlysProfile: data.carlysProfile }),
      ...(data.mentorStyle === undefined ? {} : { mentorStyle: data.mentorStyle }),
      ...(data.sex === undefined ? {} : { sex: data.sex }),
      ...(data.birthDate === undefined ? {} : { birthDate: data.birthDate }),
      ...(data.heightCm === undefined ? {} : { heightCm: data.heightCm }),
      ...(data.activityLevel === undefined ? {} : { activityLevel: data.activityLevel }),
      ...(data.nutritionGoal === undefined ? {} : { nutritionGoal: data.nutritionGoal }),
    });
    return presentUser(updated);
  }
}
