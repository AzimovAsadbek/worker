import { Module } from '@nestjs/common';
import { AttendanceModule } from '../attendance/attendance.module';
import { DisputesController } from './disputes.controller';
import { DisputesService } from './disputes.service';

@Module({ imports: [AttendanceModule], controllers: [DisputesController], providers: [DisputesService] })
export class DisputesModule {}
