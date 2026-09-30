import { Module } from '@nestjs/common';
import { SupervisorAttendanceController, WorkerAttendanceController } from './attendance.controller';
import { AttendanceJobs } from './attendance.jobs';
import { JobsController } from './jobs.controller';
import { AttendanceService } from './attendance.service';
import { ShiftsService } from './shifts.service';

@Module({
  controllers: [WorkerAttendanceController, SupervisorAttendanceController, JobsController],
  providers: [AttendanceService, ShiftsService, AttendanceJobs],
  exports: [ShiftsService, AttendanceService],
})
export class AttendanceModule {}
