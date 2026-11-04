/** Email delivery gives up after this many failed attempts. */
export const MAX_DELIVERY_ATTEMPTS = 5;

/** Backoff after the Nth failure (1-based): 1 min, 5 min, 15 min, 60 min. */
const RETRY_DELAYS_MINUTES = [1, 5, 15, 60];

const MINUTE_MS = 60_000;

export function retryDelayMs(failedAttempts: number): number {
  const index = Math.min(Math.max(failedAttempts, 1), RETRY_DELAYS_MINUTES.length) - 1;
  return RETRY_DELAYS_MINUTES[index] * MINUTE_MS;
}

/** Minutes after local midnight in an IANA time zone (e.g. "Asia/Karachi"). */
export function localMinutes(now: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const hour = Number(parts.find((p) => p.type === 'hour')?.value ?? 0);
  const minute = Number(parts.find((p) => p.type === 'minute')?.value ?? 0);
  return hour * 60 + minute;
}

/**
 * If `now` falls inside the user's quiet hours, returns when they end;
 * otherwise null (send now). Handles windows that cross midnight
 * (e.g. 22:00-07:00). Start == end, or either missing, means no quiet hours.
 */
export function quietHoursEnd(now: Date, timeZone: string, start?: number | null, end?: number | null): Date | null {
  if (start == null || end == null || start === end) return null;
  const current = localMinutes(now, timeZone);
  const inside = start < end ? current >= start && current < end : current >= start || current < end;
  if (!inside) return null;
  const minutesLeft = (end - current + 24 * 60) % (24 * 60);
  // Round to the start of the minute so the result is stable.
  const base = Math.floor(now.getTime() / MINUTE_MS) * MINUTE_MS;
  return new Date(base + minutesLeft * MINUTE_MS);
}

/** Validates an IANA time zone name. */
export function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat('en-GB', { timeZone });
    return true;
  } catch {
    return false;
  }
}
