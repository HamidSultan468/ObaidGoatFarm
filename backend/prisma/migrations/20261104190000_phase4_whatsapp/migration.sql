-- CreateEnum
CREATE TYPE "WhatsAppDirection" AS ENUM ('INBOUND', 'OUTBOUND');

-- CreateEnum
CREATE TYPE "WhatsAppMessageStatus" AS ENUM ('RECEIVED', 'PROCESSED', 'IGNORED', 'FAILED', 'SENT');

-- CreateTable
CREATE TABLE "whatsapp_configs" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "phoneNumberId" TEXT NOT NULL,
    "displayPhone" TEXT,
    "accessTokenEncrypted" TEXT NOT NULL,
    "appSecretEncrypted" TEXT NOT NULL,
    "verifyToken" TEXT NOT NULL,
    "isEnabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "whatsapp_configs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "whatsapp_links" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "phoneE164" TEXT NOT NULL,
    "verifiedAt" TIMESTAMP(3),
    "linkCodeHash" TEXT,
    "linkCodeExpiresAt" TIMESTAMP(3),
    "failedAttempts" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "whatsapp_links_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "whatsapp_message_logs" (
    "id" TEXT NOT NULL,
    "workspaceId" TEXT,
    "direction" "WhatsAppDirection" NOT NULL,
    "waMessageId" TEXT,
    "phoneE164" TEXT NOT NULL,
    "body" TEXT,
    "status" "WhatsAppMessageStatus" NOT NULL,
    "error" TEXT,
    "draftId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "whatsapp_message_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "whatsapp_configs_workspaceId_key" ON "whatsapp_configs"("workspaceId");

-- CreateIndex
CREATE UNIQUE INDEX "whatsapp_configs_phoneNumberId_key" ON "whatsapp_configs"("phoneNumberId");

-- CreateIndex
CREATE UNIQUE INDEX "whatsapp_configs_verifyToken_key" ON "whatsapp_configs"("verifyToken");

-- CreateIndex
CREATE UNIQUE INDEX "whatsapp_links_workspaceId_phoneE164_key" ON "whatsapp_links"("workspaceId", "phoneE164");

-- CreateIndex
CREATE UNIQUE INDEX "whatsapp_links_workspaceId_userId_key" ON "whatsapp_links"("workspaceId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "whatsapp_message_logs_waMessageId_key" ON "whatsapp_message_logs"("waMessageId");

-- CreateIndex
CREATE INDEX "whatsapp_message_logs_workspaceId_createdAt_idx" ON "whatsapp_message_logs"("workspaceId", "createdAt");

-- AddForeignKey
ALTER TABLE "whatsapp_configs" ADD CONSTRAINT "whatsapp_configs_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "whatsapp_links" ADD CONSTRAINT "whatsapp_links_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "whatsapp_links" ADD CONSTRAINT "whatsapp_links_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "whatsapp_message_logs" ADD CONSTRAINT "whatsapp_message_logs_workspaceId_fkey" FOREIGN KEY ("workspaceId") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

