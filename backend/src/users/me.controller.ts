import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { AuthUser } from '../common/types';
import { NotificationPrefsDto, RegisterDeviceDto, UpdateMeDto, UpsertWorkerProfileDto } from './dto/users.dto';
import { UsersService } from './users.service';

@ApiTags('me')
@ApiBearerAuth()
@Controller('me')
export class MeController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @ApiOperation({ summary: 'Current user, active memberships (roles per company) and worker profile' })
  me(@CurrentUser() user: AuthUser) {
    return this.users.getMe(user.id);
  }

  @Patch()
  update(@CurrentUser() user: AuthUser, @Body() dto: UpdateMeDto) {
    return this.users.updateMe(user.id, dto);
  }

  @Get('worker-profile')
  profile(@CurrentUser() user: AuthUser) {
    return this.users.getWorkerProfile(user.id);
  }

  @Put('worker-profile')
  @ApiOperation({ summary: 'Self-reported worker profile (shown separately from verified data)' })
  upsertProfile(@CurrentUser() user: AuthUser, @Body() dto: UpsertWorkerProfileDto) {
    return this.users.upsertWorkerProfile(user.id, dto);
  }

  @Post('memberships/:membershipId/leave')
  @HttpCode(204)
  @ApiOperation({ summary: 'Leave a company. Verified history is kept.' })
  async leave(@CurrentUser() user: AuthUser, @Param('membershipId', ParseUUIDPipe) id: string) {
    await this.users.leaveCompany(user.id, id);
  }

  @Post('devices')
  @HttpCode(204)
  @ApiOperation({ summary: 'Register an FCM push token for this user' })
  async device(@CurrentUser() user: AuthUser, @Body() dto: RegisterDeviceDto) {
    await this.users.registerDevice(user.id, dto);
  }

  @Get('notification-preferences')
  async prefs(@CurrentUser() user: AuthUser) {
    return (await this.users.getMe(user.id)).notificationPrefs;
  }

  @Put('notification-preferences')
  updatePrefs(@CurrentUser() user: AuthUser, @Body() dto: NotificationPrefsDto) {
    return this.users.updatePrefs(user.id, dto);
  }
}
