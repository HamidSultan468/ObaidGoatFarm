// Live E2E for Phase 11 (AI providers + human-approved drafts).
// No real API key is needed: provider calls use a deliberately invalid key
// (a real request to Anthropic that is rejected), and the approval flow uses
// draft rows inserted as test fixtures.
// Usage: node scripts/e2e/ai-drafts.e2e.mjs http://localhost:3000
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';

const BASE = process.argv[2] ?? 'http://localhost:3000';
const require = createRequire(import.meta.url);
const { Client } = require('pg');
const env = Object.fromEntries(readFileSync(new URL('../../.env', import.meta.url), 'utf8').split('\n').filter((l) => l.includes('=') && !l.startsWith('#')).map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim().replace(/^(['"])(.*)\1$/, '$2')]));
const db = new Client({ connectionString: env.DATABASE_URL });
await db.connect();

const run = Date.now().toString(36);
let passed = 0;
const failures = [];
async function api(method, path, token, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, body: json };
}
function check(name, condition, detail) {
  if (condition) { passed++; console.log('PASS', name); }
  else { failures.push(name); console.log('FAIL', name, JSON.stringify(detail)?.slice(0, 600)); }
}
async function login(email) {
  const r = await api('POST', '/auth/login', null, { email, password: 'TangentTest12345' });
  return r.body.accessToken ?? r.body.tokens?.accessToken;
}
const owner = await login('owner@tangentsmart.test');
const admin = await login('admin@tangentsmart.test');
const intruder = await login('intruder@tangentsmart.test');
const ws = (await api('GET', '/workspaces', owner)).body.find((w) => w.name === 'Obaid Goat Farm');
const W = `/workspaces/${ws.id}`;
const iws = (await api('GET', '/workspaces', intruder)).body[0];
const ownerId = (await api('GET', '/auth/me', owner)).body.id ?? (await api('GET', '/auth/me', owner)).body.user?.id;

// Start from a clean provider list for this workspace.
for (const p of (await api('GET', `${W}/ai/providers`, owner)).body) await api('DELETE', `${W}/ai/providers/${p.id}`, owner);

// --- Not configured -----------------------------------------------------------
const notSetUp = await api('POST', `${W}/drafts/from-text`, owner, { text: '2 bakriyan 90 hazar me bechi' });
check('no provider: clear 400 and manual entry still works', notSetUp.status === 400 && /not set up/i.test(notSetUp.body.message) && /Manual entry/i.test(notSetUp.body.message), notSetUp.body);

// --- Provider configuration ------------------------------------------------------
const fakeKeyA = `sk-ant-api03-e2e-invalid-key-${run}-AAAA`;
const badModel = await api('POST', `${W}/ai/providers`, owner, { apiKey: fakeKeyA, model: 'gpt-4o' });
check('non-Claude model id rejected 400', badModel.status === 400, badModel.body);
const shortKey = await api('POST', `${W}/ai/providers`, owner, { apiKey: 'short', model: 'claude-opus-5-5' });
check('too-short key rejected 400', shortKey.status === 400, shortKey.body);
const added = await api('POST', `${W}/ai/providers`, owner, { apiKey: fakeKeyA, model: 'claude-opus-5-5', priority: 1 });
check('add provider: key never returned, only a 4-char hint', added.status === 201 && added.body.keyHint === 'AAAA' && added.body.apiKey === undefined && added.body.apiKeyEncrypted === undefined, added.body);
const stored = (await db.query('SELECT "apiKeyEncrypted" FROM ai_provider_configs WHERE id = $1', [added.body.id])).rows[0]?.apiKeyEncrypted ?? '';
check('key is encrypted at rest (iv:tag:ciphertext, no plaintext)', /^[0-9a-f]{24}:[0-9a-f]{32}:[0-9a-f]+$/.test(stored) && !stored.includes(fakeKeyA), stored.slice(0, 40));
const adminList = await api('GET', `${W}/ai/providers`, admin);
check('ADMIN can view provider settings', adminList.status === 200 && adminList.body.length === 1, adminList.status);
const intruderList = await api('GET', `${W}/ai/providers`, intruder);
check('non-member cannot see provider settings 403', intruderList.status === 403, intruderList.status);

// --- Real call with an invalid key -----------------------------------------------
const test = await api('POST', `${W}/ai/providers/${added.body.id}/test`, owner);
check('provider test makes a real call; Anthropic rejects the key (handled, not a crash)', test.status === 201 && test.body.ok === false && /API key was rejected/.test(test.body.message), test.body);
const draftFail = await api('POST', `${W}/drafts/from-text`, owner, { text: '2 bakriyan 90 hazar me bechi, paise cash me aaye' });
check('draft from text with a bad key: 502, reason given, manual entry reminder', draftFail.status === 502 && /API key was rejected/.test(draftFail.body.message) && /Manual entry still works/.test(draftFail.body.message), draftFail.body);

// Failover: a second provider is tried after the first fails.
const addedB = await api('POST', `${W}/ai/providers`, owner, { apiKey: `sk-ant-api03-e2e-invalid-key-${run}-BBBB`, model: 'claude-sonnet-5-5', priority: 2 });
const failover = await api('POST', `${W}/drafts/from-text`, owner, { text: 'chara 5000 ka liya' });
check('failover tries every enabled provider in priority order', failover.status === 502 && /claude-opus-5-5:.*claude-sonnet-5-5:/.test(failover.body.message), failover.body);

const usage = await api('GET', `${W}/ai/providers/usage`, owner);
const usageA = usage.body.providers?.find((p) => p.configId === added.body.id);
check('usage monitoring counts this month\'s requests and failures per provider', usage.status === 200 && usageA?.requests >= 3 && usageA?.failures === usageA?.requests, usage.body);

// Monthly quota
await api('PATCH', `${W}/ai/providers/${added.body.id}`, owner, { monthlyRequestLimit: 1 });
const quota = await api('POST', `${W}/drafts/from-text`, owner, { text: 'doodh 3000 ka becha' });
check('provider over its monthly limit is skipped', quota.status === 502 && /claude-opus-5-5: monthly limit reached/.test(quota.body.message), quota.body);

// Disable all -> not set up again
await api('PATCH', `${W}/ai/providers/${added.body.id}`, owner, { isEnabled: false });
await api('PATCH', `${W}/ai/providers/${addedB.body.id}`, owner, { isEnabled: false });
const disabled = await api('POST', `${W}/drafts/from-text`, owner, { text: 'test' });
check('all providers disabled: treated as not set up (400)', disabled.status === 400, disabled.body);
const receipt404 = await api('POST', `${W}/drafts/from-receipt`, owner, { attachmentId: randomUUID() });
check('receipt draft for an unknown document 404', receipt404.status === 404, receipt404.body);

// --- Approval flow (fixture drafts) --------------------------------------------------
const accounts = (await api('GET', `${W}/accounts`, owner)).body;
const cash = accounts.find((a) => a.code === '1000');
const sales = accounts.find((a) => a.code === '4000');
const expense = accounts.find((a) => a.code === '5000');
const animal = (await api('POST', `${W}/animals`, owner, { tagNumber: `AI-${run}`, sex: 'MALE', name: 'Draft test' })).body;
const iAccounts = (await api('GET', `/workspaces/${iws.id}/accounts`, intruder)).body;

async function fixture(kind, payload, summary = `E2E ${kind} ${run}`) {
  const id = randomUUID();
  await db.query(
    `INSERT INTO record_drafts (id, "workspaceId", source, kind, status, summary, payload, warnings, "createdByUserId", "createdAt")
     VALUES ($1, $2, 'AI_TEXT', $3, 'PENDING', $4, $5, '[]', $6, now() AT TIME ZONE 'UTC')`,
    [id, ws.id, kind, summary, JSON.stringify(payload), ownerId],
  );
  return id;
}

const incomeDraft = await fixture('INCOME', { amount: '2500', toAccountId: cash.id, incomeAccountId: sales.id, animalId: animal.id, contactId: null, landParcelId: null, memo: null });
const listed = await api('GET', `${W}/drafts?status=PENDING`, owner);
check('pending drafts are listed', listed.status === 200 && listed.body.some((d) => d.id === incomeDraft), listed.body.length);
const approved = await api('POST', `${W}/drafts/${incomeDraft}/approve`, owner, {});
check('approve: income posted through the real ledger', approved.status === 201 && approved.body.result?.type === 'JournalEntry' && approved.body.draft.status === 'APPROVED', approved.body);
const ledger = (await api('GET', `${W}/animals/${animal.id}/ledger`, owner)).body;
check('posted income shows on the animal\'s finances (2500.0000)', ledger.income === '2500.0000', ledger);
const again = await api('POST', `${W}/drafts/${incomeDraft}/approve`, owner, {});
check('approving twice is refused 409 (idempotent)', again.status === 409, again.body);

const incomplete = await fixture('EXPENSE', { amount: '750', fromAccountId: cash.id, expenseAccountId: null, animalId: animal.id });
const blocked = await api('POST', `${W}/drafts/${incomplete}/approve`, owner, {});
const stillPending = (await api('GET', `${W}/drafts/${incomplete}`, owner)).body.status;
check('incomplete draft: 400 with field errors, stays PENDING', blocked.status === 400 && Array.isArray(blocked.body.details) && blocked.body.details.length > 0 && stillPending === 'PENDING', blocked.body);
const forged = await api('POST', `${W}/drafts/${incomplete}/approve`, owner, { payload: { amount: '750', fromAccountId: cash.id, expenseAccountId: expense.id, workspaceId: iws.id } });
check('edited payload with an unexpected field (workspaceId) rejected 400', forged.status === 400, forged.body);
const crossTenant = await api('POST', `${W}/drafts/${incomplete}/approve`, owner, { payload: { amount: '750', fromAccountId: cash.id, expenseAccountId: iAccounts.find((a) => a.code === '5000').id } });
const afterCross = (await api('GET', `${W}/drafts/${incomplete}`, owner)).body.status;
check('draft pointing at another tenant\'s account refused by the ledger, draft back to PENDING', crossTenant.status === 400 && afterCross === 'PENDING', { status: crossTenant.status, body: crossTenant.body, afterCross });
const fixed = await api('POST', `${W}/drafts/${incomplete}/approve`, owner, { payload: { amount: '750', fromAccountId: cash.id, expenseAccountId: expense.id, animalId: animal.id } });
check('reviewer corrects the draft and approves: expense posted', fixed.status === 201 && fixed.body.result?.type === 'JournalEntry', fixed.body);

const race = await fixture('EXPENSE', { amount: '111', fromAccountId: cash.id, expenseAccountId: expense.id }, `E2E race ${run}`);
const [r1, r2, r3] = await Promise.all([1, 2, 3].map(() => api('POST', `${W}/drafts/${race}/approve`, owner, {})));
const statuses = [r1.status, r2.status, r3.status].sort();
const posted = (await db.query(`SELECT count(*)::int AS n FROM journal_entries WHERE "workspaceId" = $1 AND memo = $2`, [ws.id, `E2E race ${run}`])).rows[0].n;
check('three simultaneous approvals: exactly one succeeds, one entry posted', JSON.stringify(statuses) === JSON.stringify([201, 409, 409]) && posted === 1, { statuses, posted });

const health = await fixture('ANIMAL_HEALTH', { animalId: animal.id, type: 'DEWORMING', recordDate: '2026-11-04', description: 'Albendazole', medication: 'Albendazole', dosage: null, veterinarian: null, nextDueDate: '2027-02-04' });
const healthOk = await api('POST', `${W}/drafts/${health}/approve`, owner, {});
const records = (await api('GET', `${W}/animals/${animal.id}/health-records`, owner)).body;
check('health draft approved: health record created', healthOk.status === 201 && records.some((r) => r.id === healthOk.body.result?.id && r.type === 'DEWORMING'), healthOk.body);
const weight = await fixture('ANIMAL_WEIGHT', { animalId: animal.id, weightKg: '41.250', recordDate: '2026-11-04' });
const weightOk = await api('POST', `${W}/drafts/${weight}/approve`, owner, {});
const weights = (await api('GET', `${W}/animals/${animal.id}/weights`, owner)).body;
check('weight draft approved: exact decimal weight stored', weightOk.status === 201 && weights.some((w) => w.weightKg === '41.25'), weights);

const toReject = await fixture('INCOME', { amount: '99', toAccountId: cash.id, incomeAccountId: sales.id });
const rejected = await api('POST', `${W}/drafts/${toReject}/reject`, owner, { reason: 'Duplicate' });
const approveRejected = await api('POST', `${W}/drafts/${toReject}/approve`, owner, {});
check('rejected draft cannot be approved later (409)', rejected.status === 201 && rejected.body.status === 'REJECTED' && approveRejected.status === 409, [rejected.body, approveRejected.status]);
const outsider = await api('POST', `${W}/drafts/${toReject}/reject`, intruder, {});
check('non-member cannot review drafts 403', outsider.status === 403, outsider.status);

// Cleanup: remove the test providers.
for (const p of (await api('GET', `${W}/ai/providers`, owner)).body) await api('DELETE', `${W}/ai/providers/${p.id}`, owner);
await db.end();
console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }
