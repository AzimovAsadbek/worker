import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, Res, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CompanyMembership } from '@prisma/client';
import type { Response } from 'express';
import { memoryStorage } from 'multer';
import { CompanyRoles, SUPERVISOR_ROLES } from '../common/decorators/company-roles.decorator';
import { CurrentMembership, CurrentUser, ReqMeta } from '../common/decorators/current-user.decorator';
import type { AuthUser, RequestMeta } from '../common/types';
import { CreateTaskDto, EvidenceFieldsDto, ListTasksQuery, ReviewTaskDto, SubmitTaskDto } from './dto/tasks.dto';
import { TasksService } from './tasks.service';

const MAX_UPLOAD = Number(process.env.UPLOAD_MAX_BYTES || 8 * 1024 * 1024);

@ApiTags('tasks (supervisor)')
@Controller('companies/:companyId/tasks')
export class SupervisorTasksController {
  constructor(private readonly tasks: TasksService) {}

  @Post()
  @CompanyRoles(...SUPERVISOR_ROLES)
  create(@CurrentMembership() m: CompanyMembership, @Body() dto: CreateTaskDto, @ReqMeta() meta: RequestMeta) {
    return this.tasks.create(m, dto, meta);
  }

  @Get()
  @CompanyRoles(...SUPERVISOR_ROLES)
  list(@CurrentMembership() m: CompanyMembership, @Query() q: ListTasksQuery) {
    return this.tasks.list(m, q);
  }

  @Get(':taskId')
  @CompanyRoles(...SUPERVISOR_ROLES)
  get(@CurrentMembership() m: CompanyMembership, @Param('taskId', ParseUUIDPipe) id: string) {
    return this.tasks.getForSupervisor(m, id);
  }

  @Post(':taskId/review')
  @HttpCode(200)
  @CompanyRoles(...SUPERVISOR_ROLES)
  @ApiOperation({ summary: 'Approve / reject / request changes on a submitted task' })
  review(@CurrentMembership() m: CompanyMembership, @Param('taskId', ParseUUIDPipe) id: string, @Body() dto: ReviewTaskDto, @ReqMeta() meta: RequestMeta) {
    return this.tasks.review(m, id, dto, meta);
  }

  @Post(':taskId/cancel')
  @HttpCode(204)
  @CompanyRoles(...SUPERVISOR_ROLES)
  async cancel(@CurrentMembership() m: CompanyMembership, @Param('taskId', ParseUUIDPipe) id: string, @ReqMeta() meta: RequestMeta) {
    await this.tasks.cancel(m, id, meta);
  }
}

@ApiTags('tasks (worker)')
@ApiBearerAuth()
@Controller()
export class WorkerTasksController {
  constructor(private readonly tasks: TasksService) {}

  @Get('me/tasks')
  list(@CurrentUser() user: AuthUser, @Query() q: ListTasksQuery) {
    return this.tasks.myTasks(user.id, q);
  }

  @Get('me/tasks/:taskId')
  get(@CurrentUser() user: AuthUser, @Param('taskId', ParseUUIDPipe) id: string) {
    return this.tasks.myTask(user.id, id);
  }

  @Post('me/tasks/:taskId/start')
  @HttpCode(200)
  start(@CurrentUser() user: AuthUser, @Param('taskId', ParseUUIDPipe) id: string) {
    return this.tasks.start(user.id, id);
  }

  @Post('me/tasks/:taskId/submit')
  @HttpCode(200)
  submit(@CurrentUser() user: AuthUser, @Param('taskId', ParseUUIDPipe) id: string, @Body() dto: SubmitTaskDto) {
    return this.tasks.submit(user.id, id, dto);
  }

  @Post('me/tasks/:taskId/evidence')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: {
        file: { type: 'string', format: 'binary' },
        comment: { type: 'string' },
        capturedAt: { type: 'string', format: 'date-time' },
        latitude: { type: 'number' },
        longitude: { type: 'number' },
      },
    },
  })
  @ApiOperation({ summary: 'Upload a photo (JPEG/PNG/WEBP) or PDF. Content is validated by magic bytes.' })
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: MAX_UPLOAD, files: 1, fields: 10, fieldSize: 4096 } }))
  upload(
    @CurrentUser() user: AuthUser,
    @Param('taskId', ParseUUIDPipe) id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
    @Body() fields: EvidenceFieldsDto,
  ) {
    return this.tasks.addEvidence(user.id, id, file, fields);
  }

  @Get('evidence/:evidenceId/content')
  @ApiOperation({ summary: 'Stream an evidence file (uploader or supervisor of the site only)' })
  async content(@CurrentUser() user: AuthUser, @Param('evidenceId', ParseUUIDPipe) id: string, @Res() res: Response) {
    const file = await this.tasks.evidenceForDownload(user.id, id);
    res.setHeader('Content-Type', file.mimeType);
    res.setHeader('Content-Length', String(file.sizeBytes));
    res.setHeader('Content-Disposition', `inline; filename="evidence-${file.id}"`);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'private, max-age=300');
    res.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    file.stream.on('error', () => res.destroy());
    file.stream.pipe(res);
  }
}
