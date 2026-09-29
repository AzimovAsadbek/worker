import { Global, Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module';
import { FcmSender } from './fcm.sender';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Global()
@Module({
  imports: [UsersModule],
  controllers: [NotificationsController],
  providers: [NotificationsService, FcmSender],
  exports: [NotificationsService],
})
export class NotificationsModule {}
