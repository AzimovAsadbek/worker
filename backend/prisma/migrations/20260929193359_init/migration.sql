-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "Role" AS ENUM ('COMPANY_ADMIN', 'MANAGER', 'FOREMAN', 'WORKER');

-- CreateEnum
CREATE TYPE "MembershipStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'REMOVED');

-- CreateEnum
CREATE TYPE "CompanyVerificationStatus" AS ENUM ('UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED');

-- CreateEnum
CREATE TYPE "ProjectStatus" AS ENUM ('PLANNED', 'ACTIVE', 'ON_HOLD', 'COMPLETED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "SiteStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "AssignmentStatus" AS ENUM ('ACTIVE', 'ENDED');

-- CreateEnum
CREATE TYPE "ShiftStatus" AS ENUM ('OPEN', 'CLOSED', 'NEEDS_REVIEW', 'VERIFIED', 'REJECTED');

-- CreateEnum
CREATE TYPE "WorkEventType" AS ENUM ('WORK_STARTED', 'WORK_ENDED', 'SHIFT_AUTO_CLOSED', 'SHIFT_VERIFIED', 'SHIFT_REJECTED', 'SHIFT_CORRECTED', 'TASK_ASSIGNED', 'TASK_STARTED', 'TASK_SUBMITTED', 'TASK_APPROVED', 'TASK_REJECTED', 'TASK_CHANGES_REQUESTED', 'DISPUTE_OPENED', 'DISPUTE_RESOLVED');

-- CreateEnum
CREATE TYPE "EventSource" AS ENUM ('MOBILE_APP', 'FOREMAN_APP', 'KIOSK', 'SYSTEM');

-- CreateEnum
CREATE TYPE "TaskStatus" AS ENUM ('ASSIGNED', 'IN_PROGRESS', 'SUBMITTED', 'CHANGES_REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ApprovalDecision" AS ENUM ('APPROVED', 'REJECTED', 'CHANGES_REQUESTED');

-- CreateEnum
CREATE TYPE "EvidenceKind" AS ENUM ('PHOTO', 'DOCUMENT');

-- CreateEnum
CREATE TYPE "VacancyStatus" AS ENUM ('DRAFT', 'OPEN', 'PAUSED', 'CLOSED', 'FILLED');

-- CreateEnum
CREATE TYPE "PaymentPeriod" AS ENUM ('HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY', 'PER_TASK');

-- CreateEnum
CREATE TYPE "ApplicationStatus" AS ENUM ('SUBMITTED', 'SHORTLISTED', 'ACCEPTED', 'REJECTED', 'WITHDRAWN');

-- CreateEnum
CREATE TYPE "DisputeStatus" AS ENUM ('OPEN', 'ACCEPTED', 'REJECTED');

-- CreateEnum
CREATE TYPE "WorkerAvailability" AS ENUM ('AVAILABLE', 'EMPLOYED', 'NOT_LOOKING');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "phone" TEXT NOT NULL,
    "fullName" VARCHAR(120),
    "locale" VARCHAR(8) NOT NULL DEFAULT 'uz',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isPlatformAdmin" BOOLEAN NOT NULL DEFAULT false,
    "notificationPrefs" JSONB NOT NULL DEFAULT '{}',
    "lastLoginAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OtpChallenge" (
    "id" UUID NOT NULL,
    "phone" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "consumedAt" TIMESTAMP(3),
    "ip" VARCHAR(64),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OtpChallenge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "familyId" UUID NOT NULL,
    "refreshTokenHash" TEXT NOT NULL,
    "deviceId" VARCHAR(128),
    "deviceName" VARCHAR(120),
    "platform" VARCHAR(20),
    "ip" VARCHAR(64),
    "userAgent" VARCHAR(255),
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "lastUsedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),
    "revokedReason" VARCHAR(40),
    "rotatedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DeviceToken" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "token" TEXT NOT NULL,
    "platform" VARCHAR(20) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DeviceToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Company" (
    "id" UUID NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "industry" VARCHAR(40) NOT NULL DEFAULT 'CONSTRUCTION',
    "description" VARCHAR(2000),
    "phone" VARCHAR(20),
    "region" VARCHAR(80),
    "city" VARCHAR(80),
    "address" VARCHAR(255),
    "timezone" VARCHAR(40) NOT NULL DEFAULT 'Asia/Tashkent',
    "registrationNumber" VARCHAR(20),
    "verificationStatus" "CompanyVerificationStatus" NOT NULL DEFAULT 'UNVERIFIED',
    "verificationNote" VARCHAR(500),
    "verifiedAt" TIMESTAMP(3),
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Company_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompanyMembership" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "role" "Role" NOT NULL,
    "status" "MembershipStatus" NOT NULL DEFAULT 'ACTIVE',
    "title" VARCHAR(80),
    "invitedById" UUID,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "removedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CompanyMembership_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompanyWorkerBlock" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CompanyWorkerBlock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Project" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "description" VARCHAR(2000),
    "address" VARCHAR(255),
    "status" "ProjectStatus" NOT NULL DEFAULT 'ACTIVE',
    "startDate" DATE,
    "endDate" DATE,
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Project_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Site" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "projectId" UUID NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "address" VARCHAR(255),
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "radiusMeters" INTEGER NOT NULL DEFAULT 200,
    "timezone" VARCHAR(40) NOT NULL DEFAULT 'Asia/Tashkent',
    "shiftStart" VARCHAR(5) NOT NULL DEFAULT '08:00',
    "shiftEnd" VARCHAR(5) NOT NULL DEFAULT '18:00',
    "lateGraceMinutes" INTEGER NOT NULL DEFAULT 15,
    "workDays" INTEGER[] DEFAULT ARRAY[1, 2, 3, 4, 5, 6]::INTEGER[],
    "status" "SiteStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdById" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Site_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SiteAssignment" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "role" "Role" NOT NULL,
    "isResident" BOOLEAN NOT NULL DEFAULT false,
    "status" "AssignmentStatus" NOT NULL DEFAULT 'ACTIVE',
    "startDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate" TIMESTAMP(3),
    "assignedById" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SiteAssignment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkerProfile" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "primaryTrade" VARCHAR(80),
    "trades" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "selfReportedExperienceYears" INTEGER,
    "bio" VARCHAR(1000),
    "region" VARCHAR(80),
    "city" VARCHAR(80),
    "availability" "WorkerAvailability" NOT NULL DEFAULT 'AVAILABLE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WorkerProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Shift" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "businessDate" DATE NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "endedAt" TIMESTAMP(3),
    "originalStartAt" TIMESTAMP(3) NOT NULL,
    "originalEndAt" TIMESTAMP(3),
    "status" "ShiftStatus" NOT NULL DEFAULT 'OPEN',
    "isResident" BOOLEAN NOT NULL DEFAULT false,
    "isLate" BOOLEAN NOT NULL DEFAULT false,
    "lateMinutes" INTEGER NOT NULL DEFAULT 0,
    "workedMinutes" INTEGER NOT NULL DEFAULT 0,
    "breakMinutes" INTEGER NOT NULL DEFAULT 0,
    "verifiedMinutes" INTEGER NOT NULL DEFAULT 0,
    "flags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "verifiedById" UUID,
    "verifiedAt" TIMESTAMP(3),
    "reviewNote" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Shift_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkEvent" (
    "id" UUID NOT NULL,
    "clientEventId" VARCHAR(64),
    "companyId" UUID NOT NULL,
    "siteId" UUID,
    "shiftId" UUID,
    "subjectUserId" UUID NOT NULL,
    "actorUserId" UUID NOT NULL,
    "type" "WorkEventType" NOT NULL,
    "source" "EventSource" NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "accuracyMeters" DOUBLE PRECISION,
    "isMocked" BOOLEAN,
    "distanceMeters" DOUBLE PRECISION,
    "insideGeofence" BOOLEAN,
    "deviceId" VARCHAR(128),
    "entityType" VARCHAR(40),
    "entityId" UUID,
    "reason" VARCHAR(500),
    "flags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WorkEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Task" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "assigneeId" UUID NOT NULL,
    "createdById" UUID NOT NULL,
    "title" VARCHAR(160) NOT NULL,
    "description" VARCHAR(2000),
    "quantity" DECIMAL(12,2),
    "unit" VARCHAR(16),
    "completedQuantity" DECIMAL(12,2),
    "dueDate" DATE,
    "status" "TaskStatus" NOT NULL DEFAULT 'ASSIGNED',
    "submissionNote" VARCHAR(1000),
    "startedAt" TIMESTAMP(3),
    "submittedAt" TIMESTAMP(3),
    "reviewedAt" TIMESTAMP(3),
    "reviewedById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Task_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TaskApproval" (
    "id" UUID NOT NULL,
    "taskId" UUID NOT NULL,
    "reviewerId" UUID NOT NULL,
    "decision" "ApprovalDecision" NOT NULL,
    "comment" VARCHAR(1000),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TaskApproval_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Evidence" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "taskId" UUID,
    "shiftId" UUID,
    "uploadedById" UUID NOT NULL,
    "kind" "EvidenceKind" NOT NULL,
    "storageKey" TEXT NOT NULL,
    "mimeType" VARCHAR(80) NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "sha256" VARCHAR(64) NOT NULL,
    "originalName" VARCHAR(120),
    "comment" VARCHAR(1000),
    "capturedAt" TIMESTAMP(3),
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Evidence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Dispute" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "shiftId" UUID NOT NULL,
    "openedById" UUID NOT NULL,
    "reason" VARCHAR(1000) NOT NULL,
    "claimedStart" TIMESTAMP(3),
    "claimedEnd" TIMESTAMP(3),
    "status" "DisputeStatus" NOT NULL DEFAULT 'OPEN',
    "resolution" VARCHAR(1000),
    "resolvedById" UUID,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Dispute_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Vacancy" (
    "id" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "siteId" UUID,
    "createdById" UUID NOT NULL,
    "title" VARCHAR(160) NOT NULL,
    "description" VARCHAR(4000) NOT NULL,
    "category" VARCHAR(80) NOT NULL,
    "region" VARCHAR(80),
    "city" VARCHAR(80),
    "address" VARCHAR(255),
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "rateAmount" DECIMAL(14,2) NOT NULL,
    "currency" VARCHAR(3) NOT NULL DEFAULT 'UZS',
    "paymentPeriod" "PaymentPeriod" NOT NULL,
    "workersNeeded" INTEGER NOT NULL DEFAULT 1,
    "startDate" DATE,
    "durationDays" INTEGER,
    "requirements" VARCHAR(2000),
    "status" "VacancyStatus" NOT NULL DEFAULT 'DRAFT',
    "publishedAt" TIMESTAMP(3),
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Vacancy_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Application" (
    "id" UUID NOT NULL,
    "vacancyId" UUID NOT NULL,
    "companyId" UUID NOT NULL,
    "workerId" UUID NOT NULL,
    "coverNote" VARCHAR(1000),
    "status" "ApplicationStatus" NOT NULL DEFAULT 'SUBMITTED',
    "statusReason" VARCHAR(500),
    "statusChangedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "statusChangedBy" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Application_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "companyId" UUID,
    "type" VARCHAR(40) NOT NULL,
    "category" VARCHAR(20) NOT NULL,
    "title" VARCHAR(160) NOT NULL,
    "body" VARCHAR(500) NOT NULL,
    "data" JSONB NOT NULL DEFAULT '{}',
    "dedupeKey" TEXT,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" UUID NOT NULL,
    "companyId" UUID,
    "actorUserId" UUID,
    "action" VARCHAR(60) NOT NULL,
    "entityType" VARCHAR(40) NOT NULL,
    "entityId" VARCHAR(64),
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "ip" VARCHAR(64),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_phone_key" ON "User"("phone");

-- CreateIndex
CREATE INDEX "OtpChallenge_phone_createdAt_idx" ON "OtpChallenge"("phone", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Session_refreshTokenHash_key" ON "Session"("refreshTokenHash");

-- CreateIndex
CREATE INDEX "Session_userId_revokedAt_idx" ON "Session"("userId", "revokedAt");

-- CreateIndex
CREATE INDEX "Session_familyId_idx" ON "Session"("familyId");

-- CreateIndex
CREATE UNIQUE INDEX "DeviceToken_token_key" ON "DeviceToken"("token");

-- CreateIndex
CREATE INDEX "DeviceToken_userId_idx" ON "DeviceToken"("userId");

-- CreateIndex
CREATE INDEX "CompanyMembership_userId_status_idx" ON "CompanyMembership"("userId", "status");

-- CreateIndex
CREATE INDEX "CompanyMembership_companyId_role_status_idx" ON "CompanyMembership"("companyId", "role", "status");

-- CreateIndex
CREATE UNIQUE INDEX "CompanyMembership_companyId_userId_key" ON "CompanyMembership"("companyId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "CompanyWorkerBlock_companyId_userId_key" ON "CompanyWorkerBlock"("companyId", "userId");

-- CreateIndex
CREATE INDEX "Project_companyId_deletedAt_idx" ON "Project"("companyId", "deletedAt");

-- CreateIndex
CREATE INDEX "Site_companyId_deletedAt_idx" ON "Site"("companyId", "deletedAt");

-- CreateIndex
CREATE INDEX "Site_projectId_idx" ON "Site"("projectId");

-- CreateIndex
CREATE INDEX "SiteAssignment_siteId_status_idx" ON "SiteAssignment"("siteId", "status");

-- CreateIndex
CREATE INDEX "SiteAssignment_userId_status_idx" ON "SiteAssignment"("userId", "status");

-- CreateIndex
CREATE INDEX "SiteAssignment_companyId_status_idx" ON "SiteAssignment"("companyId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "WorkerProfile_userId_key" ON "WorkerProfile"("userId");

-- CreateIndex
CREATE INDEX "Shift_companyId_businessDate_idx" ON "Shift"("companyId", "businessDate");

-- CreateIndex
CREATE INDEX "Shift_siteId_businessDate_idx" ON "Shift"("siteId", "businessDate");

-- CreateIndex
CREATE INDEX "Shift_workerId_businessDate_idx" ON "Shift"("workerId", "businessDate");

-- CreateIndex
CREATE INDEX "Shift_companyId_status_idx" ON "Shift"("companyId", "status");

-- CreateIndex
CREATE INDEX "WorkEvent_subjectUserId_occurredAt_idx" ON "WorkEvent"("subjectUserId", "occurredAt");

-- CreateIndex
CREATE INDEX "WorkEvent_companyId_occurredAt_idx" ON "WorkEvent"("companyId", "occurredAt");

-- CreateIndex
CREATE INDEX "WorkEvent_shiftId_idx" ON "WorkEvent"("shiftId");

-- CreateIndex
CREATE INDEX "WorkEvent_deviceId_occurredAt_idx" ON "WorkEvent"("deviceId", "occurredAt");

-- CreateIndex
CREATE UNIQUE INDEX "WorkEvent_actorUserId_clientEventId_key" ON "WorkEvent"("actorUserId", "clientEventId");

-- CreateIndex
CREATE INDEX "Task_companyId_status_idx" ON "Task"("companyId", "status");

-- CreateIndex
CREATE INDEX "Task_siteId_status_idx" ON "Task"("siteId", "status");

-- CreateIndex
CREATE INDEX "Task_assigneeId_status_idx" ON "Task"("assigneeId", "status");

-- CreateIndex
CREATE INDEX "TaskApproval_taskId_idx" ON "TaskApproval"("taskId");

-- CreateIndex
CREATE UNIQUE INDEX "Evidence_storageKey_key" ON "Evidence"("storageKey");

-- CreateIndex
CREATE INDEX "Evidence_taskId_idx" ON "Evidence"("taskId");

-- CreateIndex
CREATE INDEX "Evidence_shiftId_idx" ON "Evidence"("shiftId");

-- CreateIndex
CREATE INDEX "Dispute_companyId_status_idx" ON "Dispute"("companyId", "status");

-- CreateIndex
CREATE INDEX "Dispute_shiftId_idx" ON "Dispute"("shiftId");

-- CreateIndex
CREATE INDEX "Vacancy_status_publishedAt_idx" ON "Vacancy"("status", "publishedAt");

-- CreateIndex
CREATE INDEX "Vacancy_companyId_status_idx" ON "Vacancy"("companyId", "status");

-- CreateIndex
CREATE INDEX "Vacancy_category_status_idx" ON "Vacancy"("category", "status");

-- CreateIndex
CREATE INDEX "Application_companyId_status_idx" ON "Application"("companyId", "status");

-- CreateIndex
CREATE INDEX "Application_workerId_status_idx" ON "Application"("workerId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "Application_vacancyId_workerId_key" ON "Application"("vacancyId", "workerId");

-- CreateIndex
CREATE UNIQUE INDEX "Notification_dedupeKey_key" ON "Notification"("dedupeKey");

-- CreateIndex
CREATE INDEX "Notification_userId_readAt_createdAt_idx" ON "Notification"("userId", "readAt", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_companyId_createdAt_idx" ON "AuditLog"("companyId", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_actorUserId_createdAt_idx" ON "AuditLog"("actorUserId", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_entityType_entityId_idx" ON "AuditLog"("entityType", "entityId");

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DeviceToken" ADD CONSTRAINT "DeviceToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Company" ADD CONSTRAINT "Company_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompanyMembership" ADD CONSTRAINT "CompanyMembership_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompanyMembership" ADD CONSTRAINT "CompanyMembership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompanyMembership" ADD CONSTRAINT "CompanyMembership_invitedById_fkey" FOREIGN KEY ("invitedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompanyWorkerBlock" ADD CONSTRAINT "CompanyWorkerBlock_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Project" ADD CONSTRAINT "Project_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Site" ADD CONSTRAINT "Site_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Site" ADD CONSTRAINT "Site_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SiteAssignment" ADD CONSTRAINT "SiteAssignment_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SiteAssignment" ADD CONSTRAINT "SiteAssignment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkerProfile" ADD CONSTRAINT "WorkerProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Shift" ADD CONSTRAINT "Shift_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Shift" ADD CONSTRAINT "Shift_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Shift" ADD CONSTRAINT "Shift_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkEvent" ADD CONSTRAINT "WorkEvent_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkEvent" ADD CONSTRAINT "WorkEvent_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkEvent" ADD CONSTRAINT "WorkEvent_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES "Shift"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Task" ADD CONSTRAINT "Task_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Task" ADD CONSTRAINT "Task_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Task" ADD CONSTRAINT "Task_assigneeId_fkey" FOREIGN KEY ("assigneeId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskApproval" ADD CONSTRAINT "TaskApproval_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "Task"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Evidence" ADD CONSTRAINT "Evidence_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Evidence" ADD CONSTRAINT "Evidence_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "Task"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Evidence" ADD CONSTRAINT "Evidence_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES "Shift"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Dispute" ADD CONSTRAINT "Dispute_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Dispute" ADD CONSTRAINT "Dispute_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES "Shift"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Vacancy" ADD CONSTRAINT "Vacancy_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Vacancy" ADD CONSTRAINT "Vacancy_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Application" ADD CONSTRAINT "Application_vacancyId_fkey" FOREIGN KEY ("vacancyId") REFERENCES "Vacancy"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Application" ADD CONSTRAINT "Application_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Application" ADD CONSTRAINT "Application_workerId_fkey" FOREIGN KEY ("workerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- ───── Invariants Prisma cannot express ─────
-- A worker can have at most one OPEN shift at a time (last line of defence against double check-in).
CREATE UNIQUE INDEX "Shift_one_open_per_worker" ON "Shift" ("workerId") WHERE "status" = 'OPEN';
-- At most one ACTIVE assignment per (site, user).
CREATE UNIQUE INDEX "SiteAssignment_one_active_per_site_user" ON "SiteAssignment" ("siteId", "userId") WHERE "status" = 'ACTIVE';
-- Coordinates sanity.
ALTER TABLE "Site" ADD CONSTRAINT "Site_lat_range" CHECK ("latitude" BETWEEN -90 AND 90);
ALTER TABLE "Site" ADD CONSTRAINT "Site_lng_range" CHECK ("longitude" BETWEEN -180 AND 180);
ALTER TABLE "Site" ADD CONSTRAINT "Site_radius_range" CHECK ("radiusMeters" BETWEEN 20 AND 5000);
ALTER TABLE "Vacancy" ADD CONSTRAINT "Vacancy_workers_needed_positive" CHECK ("workersNeeded" > 0);
ALTER TABLE "Shift" ADD CONSTRAINT "Shift_end_after_start" CHECK ("endedAt" IS NULL OR "endedAt" >= "startedAt");
-- Append-only guarantees: work events and audit log can never be updated or deleted.
CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER "WorkEvent_append_only" BEFORE UPDATE OR DELETE ON "WorkEvent" FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER "AuditLog_append_only" BEFORE UPDATE OR DELETE ON "AuditLog" FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
