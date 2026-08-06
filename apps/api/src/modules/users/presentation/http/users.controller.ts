import { type AuthUser } from '@carlys/api-contracts';
import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { UsersService } from '../../application/users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Profil de l’utilisateur connecté' })
  me(@CurrentUser() user: AuthenticatedPrincipal): Promise<AuthUser> {
    return this.users.me(user.userId);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Mise à jour du profil' })
  update(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: UpdateProfileDto,
  ): Promise<AuthUser> {
    return this.users.updateProfile(user.userId, dto);
  }
}
