import { Module } from '@nestjs/common';
import { AiModule } from '../ai/ai.module.js';
import { WhatsAppLinkController, WhatsAppSettingsController, WhatsAppWebhookController } from './whatsapp.controller.js';
import { WhatsAppService } from './whatsapp.service.js';

/** WhatsApp Business (Phase 11): signed webhook in, Graph API replies out, drafts only. */
@Module({
  imports: [AiModule],
  controllers: [WhatsAppSettingsController, WhatsAppLinkController, WhatsAppWebhookController],
  providers: [WhatsAppService],
})
export class WhatsAppModule {}
