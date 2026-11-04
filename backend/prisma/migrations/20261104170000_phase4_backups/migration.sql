-- CreateEnum
CREATE TYPE "BackupTrigger" AS ENUM ('MANUAL', 'SCHEDULED');

-- CreateEnum
CREATE TYPE "BackupStatus" AS ENUM ('RUNNING', 'COMPLETED', 'FAILED');

-- AlterTable
ALTER TABLE "workspaces" ADD COLUMN     "autoBackupEnabled" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "backupRetention" INTEGER NOT NULL DEFAULT 7;

-- CreateTable
CREATE TABLE "backups" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "trigger" "BackupTrigger" NOT NULL,
    "status" "BackupStatus" NOT NULL DEFAULT 'RUNNING',
    "provider" TEXT NOT NULL DEFAULT 'LOCAL',
    "storageKey" TEXT,
    "sizeBytes" INTEGER,
    "sha256" TEXT,
    "formatVersion" INTEGER NOT NULL DEFAULT 1,
    "counts" JSONB,
    "error" TEXT,
    "createdByUserId" TEXT,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "backups_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "backups_storageKey_key" ON "backups"("storageKey");

-- CreateIndex
CREATE INDEX "backups_workspaceId_startedAt_idx" ON "backups"("workspaceId", "startedAt");

-- AddForeignKey
ALTER TABLE "backups" ADD CONSTRAINT "backups_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

