/*
  Warnings:

  - You are about to drop the column `familyId` on the `Session` table. All the data in the column will be lost.
  - You are about to drop the column `refreshTokenHash` on the `Session` table. All the data in the column will be lost.
  - You are about to drop the column `rotatedAt` on the `Session` table. All the data in the column will be lost.

*/
-- DropIndex
DROP INDEX "Session_familyId_idx";

-- DropIndex
DROP INDEX "Session_refreshTokenHash_key";

-- AlterTable
ALTER TABLE "Session" DROP COLUMN "familyId",
DROP COLUMN "refreshTokenHash",
DROP COLUMN "rotatedAt";

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" UUID NOT NULL,
    "sessionId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "rotatedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");

-- CreateIndex
CREATE INDEX "RefreshToken_sessionId_idx" ON "RefreshToken"("sessionId");

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;
