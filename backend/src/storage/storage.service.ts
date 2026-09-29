import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { CreateBucketCommand, GetObjectCommand, HeadBucketCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import type { Readable } from 'stream';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { AppException, ErrorCode } from '../common/errors';

/** Private S3-compatible storage. Objects are never public; the API streams them after an access check. */
@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private readonly client: S3Client | null;
  private readonly bucket: string;

  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    this.bucket = config.s3.bucket;
    this.client =
      config.s3.endpoint && config.s3.accessKey && config.s3.secretKey
        ? new S3Client({
            endpoint: config.s3.endpoint,
            region: config.s3.region,
            forcePathStyle: config.s3.forcePathStyle,
            credentials: { accessKeyId: config.s3.accessKey, secretAccessKey: config.s3.secretKey },
          })
        : null;
  }

  async onModuleInit() {
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
    if (!this.client) throw this.unavailable();
    try {
      await this.client.send(new PutObjectCommand({ Bucket: this.bucket, Key: key, Body: body, ContentType: contentType }));
    } catch (e) {
      this.logger.error({ err: (e as Error).message }, 'Upload failed');
      throw this.unavailable();
    }
  }

  async get(key: string): Promise<Readable> {
    if (!this.client) throw this.unavailable();
    try {
      const res = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
      return res.Body as Readable;
    } catch {
      throw this.unavailable();
    }
  }

  async ping(): Promise<boolean> {
    if (!this.client) return false;
    try {
      await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
      return true;
    } catch {
      return false;
    }
  }
}
