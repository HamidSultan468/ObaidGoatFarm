// Live E2E for Phase 11 (WhatsApp). Sends webhook requests exactly as Meta
// does (HMAC-SHA256 signed with the app secret). Replies go to the real Graph
// API with a test token, so they are expected to be recorded as FAILED (401).
// Usage: node scripts/e2e/whatsapp.e2e.mjs http://localhost:3000
import { createHmac } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const BASE = process.argv[2] ?? 'http://localhost:3000';
const require = createRequire(import.meta.url);
const { Client } = require('pg');
const env = Object.fromEntries(readFileSync(new URL('../../.env', import.meta.url), 'utf8').split('\n').filter((l) => l.includes('=') && !l.startsWith('#')).map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim().replace(/^(['"])(.*)\1$/, '$2')]));
const db = new Client({ connectionString: env.DATABASE_URL });
await db.connect();

const run = Date.now().toString(36);
const runDigits = String(Date.now()).slice(-9);
let passed = 0;
const failures = [];
async function api(method, path, token, body, headers = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: { ...(body !== undefined ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
    body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, body: json };
}
function check(name, condition, detail) {
  if (condition) { passed++; console.log('PASS', name); }
  else { failures.push(name); console.log('FAIL', name, JSON.stringify(detail)?.slice(0, 600)); }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
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

const phoneNumberId = `10${runDigits}`;
const appSecret = `e2e-app-secret-${run}-0123456789`;
const ownerPhone = `+92300${runDigits.slice(-7)}`;
const adminPhone = `+92301${runDigits.slice(-7)}`;
let seq = 0;

/** A webhook body like Meta sends, signed like Meta signs it. */
function webhook(from, message, secret = appSecret, pnid = phoneNumberId) {
  const id = `wamid.e2e.${run}.${++seq}`;
  const body = JSON.stringify({
    object: 'whatsapp_business_account',
    entry: [{ id: 'WABA', changes: [{ field: 'messages', value: { messaging_product: 'whatsapp', metadata: { phone_number_id: pnid }, messages: [{ id, from: from.replace('+', ''), timestamp: '1', ...message }] } }] }],
  });
  const signature = `sha256=${createHmac('sha256', secret).update(body).digest('hex')}`;
  return { id, body, signature };
}
const text = (from, body, secret) => webhook(from, { type: 'text', text: { body } }, secret);
const send = (hook, signature = hook.signature) => api('POST', '/whatsapp/webhook', null, hook.body, { 'x-hub-signature-256': signature });
const sendUnsigned = (hook) => api('POST', '/whatsapp/webhook', null, hook.body);
async function logFor(waMessageId, wantStatus) {
  for (let i = 0; i < 40; i++) {
    const row = (await db.query('SELECT status, error, "draftId" FROM whatsapp_message_logs WHERE "waMessageId" = $1', [waMessageId])).rows[0];
    if (row && (!wantStatus || row.status !== 'RECEIVED')) return row;
    await sleep(250);
  }
  return null;
}
const outboundCount = async (phone) => (await db.query(`SELECT count(*)::int AS n FROM whatsapp_message_logs WHERE direction = 'OUTBOUND' AND "phoneE164" = $1`, [phone])).rows[0].n;
/** Replies are logged after the Graph API call returns; wait until no new ones arrive for 2 s. */
async function settledOutbound(phone) {
  let last = -1;
  for (let i = 0; i < 30; i++) {
    const n = await outboundCount(phone);
    if (n === last) return n;
    last = n;
    await sleep(2000);
  }
  return last;
}
const lastOutbound = async (phone) => {
  await settledOutbound(phone);
  return (await db.query(`SELECT status, error, body FROM whatsapp_message_logs WHERE direction = 'OUTBOUND' AND "phoneE164" = $1 ORDER BY "createdAt" DESC LIMIT 1`, [phone])).rows[0];
};

// --- Configuration -------------------------------------------------------------
await api('DELETE', `${W}/whatsapp/config`, owner);
const badConfig = await api('PUT', `${W}/whatsapp/config`, owner, { phoneNumberId: 'abc', accessToken: 'x', appSecret: 'y' });
check('invalid WhatsApp settings rejected 400', badConfig.status === 400, badConfig.body);
const saved = await api('PUT', `${W}/whatsapp/config`, owner, { phoneNumberId, displayPhone: '+92 300 0000000', accessToken: `EAAG-e2e-invalid-token-${run}`, appSecret });
check('save config: verify token issued, secrets not returned', saved.status === 200 && /^[0-9a-f]{48}$/.test(saved.body.verifyToken) && saved.body.accessToken === undefined && saved.body.appSecret === undefined, saved.body);
const stored = (await db.query('SELECT "accessTokenEncrypted", "appSecretEncrypted" FROM whatsapp_configs WHERE "workspaceId" = $1', [ws.id])).rows[0];
check('access token and app secret encrypted at rest', !stored.accessTokenEncrypted.includes('EAAG') && !stored.appSecretEncrypted.includes(appSecret) && stored.appSecretEncrypted.split(':').length === 3, null);
const clash = await api('PUT', `/workspaces/${iws.id}/whatsapp/config`, intruder, { phoneNumberId, accessToken: `EAAG-other-token-${run}-x`, appSecret: 'another-secret-0123456789' });
check('same WhatsApp number cannot be connected to two workspaces 409', clash.status === 409, clash.body);
const peek = await api('GET', `${W}/whatsapp/config`, intruder);
check('non-member cannot read WhatsApp settings 403', peek.status === 403, peek.status);
const adminView = await api('GET', `${W}/whatsapp/config`, admin);
check('ADMIN can read WhatsApp settings', adminView.status === 200 && adminView.body.configured === true, adminView.body);

// --- Webhook verification handshake -------------------------------------------------
const badVerify = await api('GET', `/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=wrong&hub.challenge=123`, null);
check('webhook verification with a wrong token 403', badVerify.status === 403, badVerify.status);
const goodVerify = await fetch(`${BASE}/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=${saved.body.verifyToken}&hub.challenge=987654`);
check('webhook verification echoes the challenge as plain text', goodVerify.status === 200 && (await goodVerify.text()) === '987654', goodVerify.status);

// --- Signature ------------------------------------------------------------------------
const unsigned = text(ownerPhone, 'hello');
check('unsigned webhook rejected 401', (await sendUnsigned(unsigned)).status === 401, null);
const forged = text(ownerPhone, 'hello', 'not-the-app-secret-000000');
check('webhook signed with the wrong secret rejected 401', (await send(forged)).status === 401, null);
const tampered = text(ownerPhone, 'hello');
check('webhook whose body was changed after signing rejected 401', (await send({ ...tampered, body: tampered.body.replace('hello', 'HELLO') }, tampered.signature)).status === 401, null);
check('nothing was recorded for rejected webhooks', (await db.query('SELECT count(*)::int AS n FROM whatsapp_message_logs WHERE "waMessageId" = ANY($1)', [[unsigned.id, forged.id, tampered.id]])).rows[0].n === 0, null);

// --- Unlinked number ----------------------------------------------------------------------
const stranger = text(ownerPhone, '2 bakriyan 90 hazar me bechi');
const strangerRes = await send(stranger);
const strangerLog = await logFor(stranger.id, true);
check('message from an unlinked number: accepted (200) but IGNORED, no draft', strangerRes.status === 200 && strangerLog?.status === 'IGNORED' && /not linked/.test(strangerLog.error) && !strangerLog.draftId, strangerLog);
const replyAttempt = await lastOutbound(ownerPhone);
check('a reply was attempted via the real Graph API (test token -> FAILED 401, recorded)', replyAttempt?.status === 'FAILED' && /Graph API 401/.test(replyAttempt.error ?? ''), replyAttempt);

// --- Linking ---------------------------------------------------------------------------------
const start = await api('POST', `${W}/whatsapp/my-link`, owner, { phone: `0${ownerPhone.slice(3)}` });
check('start linking: local number normalized, 6-digit code + instructions', start.status === 201 && start.body.phoneE164 === ownerPhone && /^\d{6}$/.test(start.body.code) && start.body.instructions.includes(`LINK ${start.body.code}`), start.body);
const codeStored = (await db.query('SELECT "linkCodeHash" FROM whatsapp_links WHERE "workspaceId" = $1 AND "phoneE164" = $2', [ws.id, ownerPhone])).rows[0]?.linkCodeHash ?? '';
check('only a hash of the link code is stored', codeStored.length === 64 && !codeStored.includes(start.body.code), null);
const wrongCode = text(ownerPhone, `LINK ${start.body.code === '000000' ? '111111' : '000000'}`);
await send(wrongCode);
check('wrong link code ignored', (await logFor(wrongCode.id, true))?.status === 'IGNORED', null);
const rightCode = text(ownerPhone, `link ${start.body.code}`);
await send(rightCode);
await logFor(rightCode.id, true);
const myLink = await api('GET', `${W}/whatsapp/my-link`, owner);
check('correct code links the phone', myLink.body?.verified === true && myLink.body.phoneE164 === ownerPhone, myLink.body);
const reuse = text(ownerPhone, `LINK ${start.body.code}`);
await send(reuse);
check('a used code cannot be reused', (await logFor(reuse.id, true))?.status === 'IGNORED', null);

const steal = await api('POST', `${W}/whatsapp/my-link`, admin, { phone: ownerPhone });
check('another member cannot claim an already-linked phone 409', steal.status === 409, steal.body);

// Brute force: 5 wrong codes burn the code.
const adminStart = await api('POST', `${W}/whatsapp/my-link`, admin, { phone: adminPhone });
for (let i = 0; i < 5; i++) {
  const guess = String((Number(adminStart.body.code) + 1 + i) % 1_000_000).padStart(6, '0');
  const hook = text(adminPhone, `LINK ${guess}`);
  await send(hook);
  await logFor(hook.id, true);
}
const late = text(adminPhone, `LINK ${adminStart.body.code}`);
await send(late);
await logFor(late.id, true);
const adminLink = await api('GET', `${W}/whatsapp/my-link`, admin);
check('after 5 wrong attempts even the right code no longer works', adminLink.body?.verified === false, adminLink.body);

// --- Linked user messages -------------------------------------------------------------------
const help = text(ownerPhone, 'help');
await send(help);
check('HELP from a linked phone is processed', (await logFor(help.id, true))?.status === 'PROCESSED', null);

for (const p of (await api('GET', `${W}/ai/providers`, owner)).body) await api('DELETE', `${W}/ai/providers/${p.id}`, owner);
const sale = text(ownerPhone, '2 bakriyan 90 hazar me bechi, paise cash me aaye');
await send(sale);
const saleLog = await logFor(sale.id, true);
check('linked text with AI not set up: FAILED with the reason, no draft created', saleLog?.status === 'FAILED' && /not set up/i.test(saleLog.error) && !saleLog.draftId, saleLog);

const voice = webhook(ownerPhone, { type: 'audio', audio: { id: 'media-1' } });
await send(voice);
const voiceLog = await logFor(voice.id, true);
check('voice note: IGNORED politely (text only for now)', voiceLog?.status === 'IGNORED' && /Unsupported message type: audio/.test(voiceLog.error), voiceLog);

// Meta retries the same message id: processed once.
const retry = text(ownerPhone, 'help');
await send(retry);
await logFor(retry.id, true);
const outboundBefore = await settledOutbound(ownerPhone);
await send(retry);
await sleep(1500);
await settledOutbound(ownerPhone);
const rows = (await db.query('SELECT count(*)::int AS n FROM whatsapp_message_logs WHERE "waMessageId" = $1', [retry.id])).rows[0].n;
const outboundAfter = (await db.query(`SELECT count(*)::int AS n FROM whatsapp_message_logs WHERE direction = 'OUTBOUND' AND "phoneE164" = $1`, [ownerPhone])).rows[0].n;
check('a retried webhook (same message id) is processed only once', rows === 1 && outboundAfter === outboundBefore, { rows, outboundBefore, outboundAfter });

const messages = await api('GET', `${W}/whatsapp/messages`, owner);
check('message log lists inbound and outbound entries', messages.status === 200 && messages.body.some((m) => m.direction === 'INBOUND') && messages.body.some((m) => m.direction === 'OUTBOUND'), messages.body.length);
const links = await api('GET', `${W}/whatsapp/links`, owner);
check('owner sees linked members', links.status === 200 && links.body.some((l) => l.phoneE164 === ownerPhone && l.verifiedAt), links.body);

// Disabled config: messages are acknowledged but not processed.
await api('PUT', `${W}/whatsapp/config`, owner, { phoneNumberId, accessToken: `EAAG-e2e-invalid-token-${run}`, appSecret, isEnabled: false });
const whileOff = text(ownerPhone, 'help');
const offRes = await send(whileOff);
await sleep(800);
const offRows = (await db.query('SELECT count(*)::int AS n FROM whatsapp_message_logs WHERE "waMessageId" = $1', [whileOff.id])).rows[0].n;
check('disabled integration: webhook acknowledged, message not processed', offRes.status === 200 && offRows === 0, { status: offRes.status, offRows });

// Cleanup this run's config (links remain for the owner to see; remove admin's unverified link).
await api('DELETE', `${W}/whatsapp/my-link`, admin);
await api('DELETE', `${W}/whatsapp/config`, owner);
await db.end();
console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }
