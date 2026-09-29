import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CompanyMembership } from '@prisma/client';
import { CompanyRoles, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, CurrentUser, ReqMeta } from '../common/decorators/current-user.decorator';
import type { AuthUser, RequestMeta } from '../common/types';
import { AttendanceService } from './attendance.service';
import {
  BulkVerifyDto,
  CorrectShiftDto,
  DashboardQuery,
  ListShiftsQuery,
  ManualEventDto,
  MyShiftsQuery,
  RejectShiftDto,
  SyncEventsDto,
  VerifyShiftDto,
} from './dto/attendance.dto';
import { ShiftsService } from './shifts.service';

@ApiTags('attendance (worker)')
@ApiBearerAuth()
@Controller()
export class WorkerAttendanceController {
  constructor(
    private readonly attendance: AttendanceService,
    private readonly shifts: ShiftsService,
  ) {}

  @Post('work-events/sync')
  @HttpCode(200)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @ApiOperation({
    summary: 'Offline-first sync of check-in / check-out events (idempotent on clientEventId)',
    description:
      'Per-event result: ACCEPTED | DUPLICATE (already stored, safe to mark synced) | REJECTED (business rule, do not retry) | RETRY (transient, retry later).',
  })
  sync(@CurrentUser() user: AuthUser, @Body() dto: SyncEventsDto) {
    return this.attendance.sync(user.id, dto.events);
  }

  @Get('me/today')
  @ApiOperation({ summary: "Worker's today: assigned sites (with geofence for offline checks), open shift, today's shifts" })
  today(@CurrentUser() user: AuthUser) {
    return this.attendance.today(user.id);
  }

  @Get('me/shifts')
  @ApiOperation({ summary: 'Own work history across all companies (portable)' })
  myShifts(@CurrentUser() user: AuthUser, @Query() q: MyShiftsQuery) {
    return this.shifts.myShifts(user.id, q);
  }

  @Get('me/shifts/:shiftId')
  myShift(@CurrentUser() user: AuthUser, @Param('shiftId', ParseUUIDPipe) id: string) {
    return this.shifts.myShift(user.id, id);
  }
}

@ApiTags('attendance (supervisor)')
@Controller('companies/:companyId')
export class SupervisorAttendanceController {
  constructor(private readonly shifts: ShiftsService) {}

  @Get('dashboard')
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Today: assigned / present / late / absent / pending checkout per site' })
  dashboard(@CurrentMembership() m: CompanyMembership, @Query() q: DashboardQuery) {
    return this.shifts.dashboard(m, q.siteId);
  }

  @Get('shifts')
  @CompanyRoles(...SUPERVISOR_ROLES)
  list(@CurrentMembership() m: CompanyMembership, @Query() q: ListShiftsQuery) {
    return this.shifts.list(m, q);
  }

  @Post('shifts/verify')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Bulk verify closed shifts' })
  bulkVerify(@CurrentMembership() m: CompanyMembership, @Body() dto: BulkVerifyDto, @ReqMeta() meta: RequestMeta) {
    return this.shifts.bulkVerify(m, dto, meta);
  }

  @Get('shifts/:shiftId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Shift with full event timeline (incl. location evidence and flags)' })
  get(@CurrentMembership() m: CompanyMembership, @Param('shiftId', ParseUUIDPipe) id: string) {
    return this.shifts.get(m, id);
  }

  @Post('shifts/:shiftId/verify')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  verify(@CurrentMembership() m: CompanyMembership, @Param('shiftId', ParseUUIDPipe) id: string, @Body() dto: VerifyShiftDto, @ReqMeta() meta: RequestMeta) {
    return this.shifts.verify(m, id, dto, meta);
  }

  @Post('shifts/:shiftId/reject')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  reject(@CurrentMembership() m: CompanyMembership, @Param('shiftId', ParseUUIDPipe) id: string, @Body() dto: RejectShiftDto, @ReqMeta() meta: RequestMeta) {
    return this.shifts.reject(m, id, dto, meta);
  }

  @Post('shifts/:shiftId/correct')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Correct start/end with a reason (appends SHIFT_CORRECTED; originals are kept)' })
  correct(@CurrentMembership() m: CompanyMembership, @Param('shiftId', ParseUUIDPipe) id: string, @Body() dto: CorrectShiftDto, @ReqMeta() meta: RequestMeta) {
    return this.shifts.correct(m, id, dto, meta);
  }

  @Post('attendance/manual')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Record check-in/out on behalf of a worker without a phone (flagged MANUAL_ENTRY)' })
  manual(@CurrentMembership() m: CompanyMembership, @Body() dto: ManualEventDto) {
    return this.shifts.manual(m, dto);
  }
}
