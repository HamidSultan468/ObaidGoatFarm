export interface AppConfig {
  nodeEnv: string;
  port: number;
  databaseUrl: string;
  encryptionKey: string;
  /** Root folder for encrypted uploaded files (Documents module). */
  storageDir: string;
  /** Graph API version for WhatsApp replies, e.g. v21.0. */
  whatsappGraphVersion: string;
  /** Null when SMTP_HOST is not set: email notifications are then disabled. */
  smtp: { host: string; port: number; secure: boolean; user?: string; pass?: string; from: string } | null;
  jwt: {
    accessSecret: string;
    refreshSecret: string;
    accessExpiresIn: string;
    refreshExpiresIn: string;
    mfaChallengeExpiresIn: string;
  };
}

export default (): AppConfig => ({
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number.parseInt(process.env.PORT ?? '3000', 10),
  databaseUrl: process.env.DATABASE_URL ?? '',
  encryptionKey: process.env.ENCRYPTION_KEY ?? '',
  storageDir: process.env.STORAGE_DIR ?? 'storage',
  whatsappGraphVersion: process.env.WHATSAPP_GRAPH_VERSION ?? 'v21.0',
  smtp: process.env.SMTP_HOST
    ? {
        host: process.env.SMTP_HOST,
        port: Number.parseInt(process.env.SMTP_PORT ?? '587', 10),
        secure: process.env.SMTP_SECURE === 'true',
        user: process.env.SMTP_USER || undefined,
        pass: process.env.SMTP_PASS || undefined,
        from: process.env.SMTP_FROM ?? 'no-reply@localhost',
      }
    : null,
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET ?? '',
    refreshSecret: process.env.JWT_REFRESH_SECRET ?? '',
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '30d',
    mfaChallengeExpiresIn: process.env.JWT_MFA_CHALLENGE_EXPIRES_IN ?? '5m',
  },
});
