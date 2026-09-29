import { Module } from '@nestjs/common';
import { SupervisorTasksController, WorkerTasksController } from './tasks.controller';
import { TasksService } from './tasks.service';

@Module({ controllers: [SupervisorTasksController, WorkerTasksController], providers: [TasksService] })
export class TasksModule {}
