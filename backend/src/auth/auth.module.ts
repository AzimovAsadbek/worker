import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { UsersModule } from '../users/users.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { DevSmsProvider, EskizSmsProvider, SmsProvider } from './sms/sms.provider';
import { TokenService } from './token.service';

@Module({
  imports: [
    UsersModule,
    JwtModule.registerAsync({
      global: true,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => ({
        secret: config.jwt.accessSecret,
        signOptions: { algorithm: 'HS256', issuer: 'worker-os' },
        verifyOptions: { algorithms: ['HS256'], issuer: 'worker-os' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    TokenService,
    {
      provide: SmsProvider,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => (config.otp.provider === 'eskiz' ? new EskizSmsProvider(config) : new DevSmsProvider()),
    },
  ],
  exports: [TokenService],
})
export class AuthModule {}
