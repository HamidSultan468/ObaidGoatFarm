import { createHash } from 'node:crypto';

/** Accepted key format: 8-100 chars of letters, digits, dash, underscore (UUIDs fit). */
export const IDEMPOTENCY_KEY_PATTERN = /^[A-Za-z0-9_-]{8,100}$/;

/** Stored results are kept this long; a retry after that is treated as new. */
export const IDEMPOTENCY_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/** JSON with object keys sorted, so the same body always hashes the same. */
export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value ?? null);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, v]) => v !== undefined)
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${canonicalJson(v)}`).join(',')}}`;
}

export function requestHash(method: string, path: string, body: unknown): string {
  return createHash('sha256').update(`${method.toUpperCase()} ${path}\n${canonicalJson(body)}`).digest('hex');
}

/**
 * Optimistic concurrency: the client sends the version it edited from as
 * `If-Match: "<updatedAt ISO>"` (quotes and a W/ prefix tolerated). Returns
 * true when there is no precondition or it matches the current version.
 */
export function versionMatches(ifMatch: string | undefined, currentUpdatedAt: Date): boolean {
  if (!ifMatch) return true;
  const value = ifMatch.trim().replace(/^W\//, '').replace(/^"(.*)"$/, '$1');
  const expected = new Date(value);
  return !Number.isNaN(expected.getTime()) && expected.getTime() === currentUpdatedAt.getTime();
}
