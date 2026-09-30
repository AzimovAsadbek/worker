import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { CreateBucketCommand, GetObjectCommand, HeadBucketCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { Readable } from 'stream';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { AppException, ErrorCode } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Private file storage. Objects are never public; the API streams them after an access check.
 * Drivers: `s3` (any S3-compatible store) or `database` (bytes in PostgreSQL — for serverless
 * deployments such as Vercel where no S3 bucket is configured; fine for pilot-scale evidence photos).
 */
@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private readonly client: S3Client | null;
  private readonly bucket: string;
  private readonly driver: 's3' | 'database';

  constructor(
    @Inject(APP_CONFIG) config: AppConfig,
    private readonly prisma: PrismaService,
  ) {
    this.bucket = config.s3.bucket;
    this.driver = config.storageDriver;
    this.client =
      this.driver === 's3' && config.s3.endpoint && config.s3.accessKey && config.s3.secretKey
        ? new S3Client({
            endpoint: config.s3.endpoint,
            region: config.s3.region,
            forcePathStyle: config.s3.forcePathStyle,
            credentials: { accessKeyId: config.s3.accessKey, secretAccessKey: config.s3.secretKey },
          })
        : null;
  }

  async onModuleInit() {
    if (this.driver === 'database') return;
    if (!this.client) {
      this.logger.warn('Object storage is not configured — evidence uploads are disabled');
      return;
    }
    try {
      await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
    } catch {
      try {
        await this.client.send(new CreateBucketCommand({ Bucket: this.bucket }));
        this.logger.log(`Created bucket ${this.bucket}`);
      } catch (e) {
        this.logger.warn(`Object storage unavailable at startup: ${(e as Error).message}`);
      }
    }
  }

  private unavailable() {
    return new AppException(ErrorCode.STORAGE_UNAVAILABLE, 'File storage is temporarily unavailable', 503);
  }

  async put(key: string, body: Buffer, contentType: string) {
    if (this.driver === 'database') {
      await this.prisma.storedObject.create({ data: { key, contentType, sizeBytes: body.length, data: new Uint8Array(body) } });
      return;
    }
    if (!this.client) throw this.unavailable();
    try {
      await this.client.send(new PutObjectCommand({ Bucket: this.bucket, Key: key, Body: body, ContentType: contentType }));
    } catch (e) {
      this.logger.error({ err: (e as Error).message }, 'Upload failed');
      throw this.unavailable();
    }
  }

  async get(key: string): Promise<Readable> {
    if (this.driver === 'database') {
      const obj = await this.prisma.storedObject.findUnique({ where: { key } });
      if (!obj) throw this.unavailable();
      return Readable.from(Buffer.from(obj.data));
    }
    if (!this.client) throw this.unavailable();
    try {
      const res = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
      return res.Body as Readable;
    } catch {
      throw this.unavailable();
    }
  }

  async ping(): Promise<boolean> {
    if (this.driver === 'database') return true;
    if (!this.client) return false;
    try {
      await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
      return true;
    } catch {
      return false;
    }
  }
}
