import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer, { type Transporter } from 'nodemailer';
import type { AppConfig } from '../../config/configuration.js';

const escapeHtml = (value: string) =>
  value.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

/** SMTP email sender. Disabled (isConfigured = false) when SMTP_HOST is not set. */
@Injectable()
export class MailerService {
  private readonly logger = new Logger(MailerService.name);
  private readonly transporter: Transporter | null;
  private readonly from: string;

  constructor(config: ConfigService) {
    const smtp = config.get<AppConfig['smtp']>('smtp') ?? null;
    this.from = smtp?.from ?? '';
    this.transporter = smtp
      ? nodemailer.createTransport({
          host: smtp.host,
          port: smtp.port,
          secure: smtp.secure,
          auth: smtp.user ? { user: smtp.user, pass: smtp.pass } : undefined,
          connectionTimeout: 10_000,
          greetingTimeout: 10_000,
          socketTimeout: 20_000,
        })
      : null;
    if (!this.transporter) {
      this.logger.log('SMTP not configured: email notifications are disabled');
    }
  }

  get isConfigured(): boolean {
    return this.transporter !== null;
  }

  /** Throws on failure so the delivery worker can retry. */
  async send(to: string, subject: string, body: string): Promise<void> {
    if (!this.transporter) {
      throw new Error('Email is not configured');
    }
    await this.transporter.sendMail({
      from: this.from,
      to,
      subject,
      text: body,
      html: `<p>${escapeHtml(body).replace(/\n/g, '<br>')}</p><p style="color:#6b7280;font-size:12px">Tangent Smart Manager</p>`,
    });
  }
}
