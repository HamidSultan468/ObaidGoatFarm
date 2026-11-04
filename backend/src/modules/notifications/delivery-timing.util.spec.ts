import { describe, expect, it } from 'vitest';
import { isValidTimeZone, localMinutes, quietHoursEnd, retryDelayMs } from './delivery-timing.util.js';

// Asia/Karachi is UTC+5 with no daylight saving, so expectations are fixed.
const KHI = 'Asia/Karachi';
const at = (iso: string) => new Date(iso);

describe('retryDelayMs', () => {
  it('backs off 1, 5, 15, then 60 minutes and stays at 60', () => {
    expect([1, 2, 3, 4, 5, 9].map((n) => retryDelayMs(n) / 60_000)).toEqual([1, 5, 15, 60, 60, 60]);
  });
});

describe('localMinutes', () => {
  it('converts UTC to local minutes after midnight', () => {
    expect(localMinutes(at('2026-11-04T17:30:00Z'), KHI)).toBe(22 * 60 + 30);
    expect(localMinutes(at('2026-11-04T19:00:00Z'), KHI)).toBe(0);
  });
});

describe('quietHoursEnd', () => {
  const night = { start: 22 * 60, end: 7 * 60 }; // 22:00-07:00, crosses midnight

  it('returns null outside quiet hours', () => {
    expect(quietHoursEnd(at('2026-11-04T10:00:00Z'), KHI, night.start, night.end)).toBeNull(); // 15:00 local
  });

  it('delays to 07:00 local when inside a window that crosses midnight', () => {
    // 23:30 local -> 07:00 local next day = 02:00 UTC
    expect(quietHoursEnd(at('2026-11-04T18:30:00Z'), KHI, night.start, night.end)?.toISOString()).toBe('2026-11-05T02:00:00.000Z');
    // 03:00 local -> 07:00 local same day
    expect(quietHoursEnd(at('2026-11-04T22:00:00Z'), KHI, night.start, night.end)?.toISOString()).toBe('2026-11-05T02:00:00.000Z');
  });

  it('handles a same-day window and its exact boundaries', () => {
    const lunch = { start: 13 * 60, end: 14 * 60 };
    expect(quietHoursEnd(at('2026-11-04T08:00:00Z'), KHI, lunch.start, lunch.end)?.toISOString()).toBe('2026-11-04T09:00:00.000Z'); // 13:00 inside
    expect(quietHoursEnd(at('2026-11-04T09:00:00Z'), KHI, lunch.start, lunch.end)).toBeNull(); // 14:00 = end, outside
  });

  it('treats missing or zero-length windows as no quiet hours', () => {
    expect(quietHoursEnd(at('2026-11-04T18:30:00Z'), KHI, null, null)).toBeNull();
    expect(quietHoursEnd(at('2026-11-04T18:30:00Z'), KHI, 600, 600)).toBeNull();
  });
});

describe('isValidTimeZone', () => {
  it('accepts IANA zones and rejects junk', () => {
    expect(isValidTimeZone('Asia/Karachi')).toBe(true);
    expect(isValidTimeZone('Mars/Olympus')).toBe(false);
  });
});
