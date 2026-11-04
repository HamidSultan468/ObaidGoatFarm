-- CreateEnum
CREATE TYPE "AiProvider" AS ENUM ('ANTHROPIC');

-- CreateEnum
CREATE TYPE "DraftSource" AS ENUM ('AI_TEXT', 'AI_RECEIPT', 'WHATSAPP');

-- CreateEnum
CREATE TYPE "DraftKind" AS ENUM ('INCOME', 'EXPENSE', 'ANIMAL_HEALTH', 'ANIMAL_WEIGHT');

-- CreateEnum
CREATE TYPE "DraftStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateTable
CREATE TABLE "ai_provider_configs" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "provider" "AiProvider" NOT NULL,
    "model" TEXT NOT NULL,
    "apiKeyEncrypted" TEXT NOT NULL,
    "keyHint" TEXT NOT NULL,
    "priority" INTEGER NOT NULL DEFAULT 1,
    "isEnabled" BOOLEAN NOT NULL DEFAULT true,
    "monthlyRequestLimit" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ai_provider_configs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_usage_logs" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "configId" TEXT,
    "provider" "AiProvider" NOT NULL,
    "model" TEXT NOT NULL,
    "feature" TEXT NOT NULL,
    "success" BOOLEAN NOT NULL,
    "inputTokens" INTEGER,
    "outputTokens" INTEGER,
    "latencyMs" INTEGER NOT NULL,
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_usage_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "record_drafts" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "source" "DraftSource" NOT NULL,
    "kind" "DraftKind" NOT NULL,
    "status" "DraftStatus" NOT NULL DEFAULT 'PENDING',
    "summary" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "rawInput" TEXT,
    "warnings" JSONB,
    "attachmentId" TEXT,
    "sourcePhone" TEXT,
    "createdByUserId" TEXT,
    "reviewedByUserId" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "rejectReason" TEXT,
    "resultType" TEXT,
    "resultId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "record_drafts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ai_provider_configs_workspaceId_priority_idx" ON "ai_provider_configs"("workspaceId", "priority");

-- CreateIndex
CREATE INDEX "ai_usage_logs_workspaceId_createdAt_idx" ON "ai_usage_logs"("workspaceId", "createdAt");

-- CreateIndex
CREATE INDEX "ai_usage_logs_configId_createdAt_idx" ON "ai_usage_logs"("configId", "createdAt");

-- CreateIndex
CREATE INDEX "record_drafts_workspaceId_status_createdAt_idx" ON "record_drafts"("workspaceId", "status", "createdAt");

-- AddForeignKey
ALTER TABLE "ai_provider_configs" ADD CONSTRAINT "ai_provider_configs_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_usage_logs" ADD CONSTRAINT "ai_usage_logs_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_usage_logs" ADD CONSTRAINT "ai_usage_logs_configId_fkey" FOREIGN KEY ("configId") REFERENCES "ai_provider_configs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "record_drafts" ADD CONSTRAINT "record_drafts_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

