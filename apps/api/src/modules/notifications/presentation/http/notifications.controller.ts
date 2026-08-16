import { type NotificationPreferencesResponse } from '@carlys/api-contracts';
import { Body, Controller, Delete, Get, HttpCode, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { NotificationsService } from '../../application/notifications.service';
import { ForgetDeviceTokenDto, RegisterDeviceTokenDto } from './dto/device-token.dto';
import { UpdateNotificationPreferenceDto } from './dto/notification-preference.dto';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('preferences')
  @ApiOperation({
    summary:
      'Ce que la personne accepte de recevoir. Une catégorie jamais réglée ' + 'vaut « acceptée ».',
  })
  preferences(
    @CurrentUser() user: AuthenticatedPrincipal,
  ): Promise<NotificationPreferencesResponse> {
    return this.notifications.preferencesOf(user.userId);
  }

  @Patch('preferences')
  @HttpCode(204)
  @ApiOperation({
    summary: 'Accepter ou refuser une catégorie (idempotent)',
    description:
      'Le refus est respecté à l’ENVOI, côté serveur : une préférence que ' +
      'seul le téléphone connaîtrait laisserait la notification arriver.',
  })
  setPreference(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: UpdateNotificationPreferenceDto,
  ): Promise<void> {
    return this.notifications.setPreference(user.userId, dto.category, dto.enabled);
  }

  @Post('device-tokens')
  @HttpCode(204)
  @ApiOperation({
    summary:
      "Enregistrer le jeton push de l'appareil (idempotent — rejouer ou " +
      'changer de compte réaffecte le jeton)',
  })
  register(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: RegisterDeviceTokenDto,
  ): Promise<void> {
    return this.notifications.registerDevice(user.userId, {
      token: dto.token,
      platform: dto.platform,
    });
  }

  @Delete('device-tokens')
  @HttpCode(204)
  @ApiOperation({ summary: 'Oublier un jeton à la déconnexion (idempotent)' })
  forget(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: ForgetDeviceTokenDto,
  ): Promise<void> {
    return this.notifications.forgetDevice(user.userId, dto.token);
  }
}
