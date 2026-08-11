import { Body, Controller, Delete, HttpCode, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { NotificationsService } from '../../application/notifications.service';
import { ForgetDeviceTokenDto, RegisterDeviceTokenDto } from './dto/device-token.dto';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications/device-tokens')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post()
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

  @Delete()
  @HttpCode(204)
  @ApiOperation({ summary: 'Oublier un jeton à la déconnexion (idempotent)' })
  forget(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: ForgetDeviceTokenDto,
  ): Promise<void> {
    return this.notifications.forgetDevice(user.userId, dto.token);
  }
}
