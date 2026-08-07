import { type AuthUser } from '@carlys/api-contracts';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { type ActivityLevel, type BiologicalSex, type NutritionGoal } from '@prisma/client';
import { presentUser } from '../../auth/application/user.presenter';
import { UsersRepository } from '../infrastructure/users.repository';

export interface UpdateProfileInput {
  displayName?: string;
  locale?: string;
  timezone?: string;
  sex?: BiologicalSex;
  birthDate?: Date;
  heightCm?: number;
  activityLevel?: ActivityLevel;
  nutritionGoal?: NutritionGoal;
}

const MAX_AGE_YEARS = 120;

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
    if (data.birthDate !== undefined) {
      const oldest = new Date();
      oldest.setUTCFullYear(oldest.getUTCFullYear() - MAX_AGE_YEARS);
      if (data.birthDate < oldest) {
        throw new BadRequestException('Date de naissance invalide.');
      }
    }
    const updated = await this.users.updateProfile(userId, {
      ...(data.displayName === undefined ? {} : { displayName: data.displayName.trim() }),
      ...(data.locale === undefined ? {} : { locale: data.locale }),
      ...(data.timezone === undefined ? {} : { timezone: data.timezone }),
      ...(data.sex === undefined ? {} : { sex: data.sex }),
      ...(data.birthDate === undefined ? {} : { birthDate: data.birthDate }),
      ...(data.heightCm === undefined ? {} : { heightCm: data.heightCm }),
      ...(data.activityLevel === undefined ? {} : { activityLevel: data.activityLevel }),
      ...(data.nutritionGoal === undefined ? {} : { nutritionGoal: data.nutritionGoal }),
    });
    return presentUser(updated);
  }
}
