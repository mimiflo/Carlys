import { type AuthUser } from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { presentUser } from '../../auth/application/user.presenter';
import { UsersRepository } from '../infrastructure/users.repository';

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

  async updateProfile(
    userId: string,
    data: { displayName?: string; locale?: string; timezone?: string },
  ): Promise<AuthUser> {
    const user = await this.users.findActiveById(userId);
    if (user === null) {
      throw new NotFoundException('Compte introuvable.');
    }
    const updated = await this.users.updateProfile(userId, {
      ...(data.displayName === undefined ? {} : { displayName: data.displayName.trim() }),
      ...(data.locale === undefined ? {} : { locale: data.locale }),
      ...(data.timezone === undefined ? {} : { timezone: data.timezone }),
    });
    return presentUser(updated);
  }
}
