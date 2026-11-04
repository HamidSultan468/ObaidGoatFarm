// Live E2E for Phase 10 (Backup & Restore).
// Usage: node scripts/e2e/backup.e2e.mjs http://localhost:3000 ./storage
import { existsSync, readFileSync, unlinkSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';

const BASE = process.argv[2] ?? 'http://localhost:3000';
const STORAGE = process.argv[3] ?? './storage';
const require = createRequire(import.meta.url);
const { OTP } = require('otplib');
const run = Date.now().toString(36);
let passed = 0;
const failures = [];

async function api(method, path, token, body) {
  const isForm = body instanceof FormData;
  const res = await fetch(BASE + path, {
    method,
    headers: { ...(body && !isForm ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: isForm ? body : body ? JSON.stringify(body) : undefined,
  });
  const raw = Buffer.from(await res.arrayBuffer());
  let json;
  try { json = JSON.parse(raw.toString()); } catch { json = raw; }
  return { status: res.status, body: json, raw, headers: res.headers };
}
function check(name, condition, detail) {
  if (condition) { passed++; console.log('PASS', name); }
  else { failures.push(name); console.log('FAIL', name, JSON.stringify(detail)?.slice(0, 600)); }
}
async function login(email) {
  let r = await api('POST', '/auth/login', null, { email, password: 'TangentTest12345' });
  if (r.status >= 400) {
    await api('POST', '/auth/register', null, { email, password: 'TangentTest12345', fullName: email.split('@')[0] });
    r = await api('POST', '/auth/login', null, { email, password: 'TangentTest12345' });
  }
  return r.body.accessToken ?? r.body.tokens?.accessToken;
}
const fileForm = (buffer, name) => { const f = new FormData(); f.append('file', new Blob([buffer]), name); return f; };

const owner = await login('owner@tangentsmart.test');
const intruder = await login('intruder@tangentsmart.test');
const admin = await login('admin@tangentsmart.test');
const list = (await api('GET', '/workspaces', owner)).body;
const ws = list.find((w) => w.name === 'Obaid Goat Farm');
const W = `/workspaces/${ws.id}`;
const invite = await api('POST', `${W}/members`, owner, { email: 'admin@tangentsmart.test', role: 'ADMIN' });
check('setup: admin test user is an ADMIN member', [201, 409].includes(invite.status), invite.body);

// Baselines from the live workspace
const snapshot = async (prefix, token) => {
  const [animals, land, docs, trial, pnl] = await Promise.all([
    api('GET', `${prefix}/animals?status=ALL`, token),
    api('GET', `${prefix}/land?status=ALL`, token),
    api('GET', `${prefix}/attachments`, token),
    api('GET', `${prefix}/reports/trial-balance`, token),
    api('GET', `${prefix}/reports/profit-and-loss?from=2000-01-01&to=2100-01-01`, token),
  ]);
  return { animals: animals.body, land: land.body, docs: docs.body, trial: trial.body, pnl: pnl.body };
};
const before = await snapshot(W, owner);

// --- Create ---------------------------------------------------------------------
const status0 = await api('GET', `${W}/backups/status`, owner);
check('status: auto backup on by default, local provider connected', status0.status === 200 && status0.body.autoBackupEnabled === true && status0.body.provider.connected === true, status0.body);
const created = await api('POST', `${W}/backups`, owner);
check('manual backup COMPLETED with record counts', created.status === 201 && created.body.status === 'COMPLETED' && created.body.counts?.animals === before.animals.length, created.body);
check('counts match live data (animals, land, documents)', created.body.counts?.landParcels === before.land.length && created.body.counts?.attachments === before.docs.length, { counts: created.body.counts, land: before.land.length, docs: before.docs.length });
check('response never exposes the storage key', created.body.storageKey === undefined, Object.keys(created.body));
const backupId = created.body.id;

const onDisk = join(STORAGE, 'backups', ws.id, `${backupId}.tsmbak`);
const fileBytes = existsSync(onDisk) ? readFileSync(onDisk) : Buffer.alloc(0);
const someTag = before.animals[0]?.tagNumber ?? 'Laali';
check('file on disk is encrypted (TSMB header, no gzip/plaintext inside)', fileBytes.subarray(0, 4).toString() === 'TSMB' && !fileBytes.includes(Buffer.from(someTag)) && !(fileBytes[33] === 0x1f && fileBytes[34] === 0x8b), { size: fileBytes.length });

// --- Verify / download -------------------------------------------------------------
const verify = await api('POST', `${W}/backups/${backupId}/verify`, owner);
check('verify: valid, checksum matches, counts reported', verify.status === 201 && verify.body.valid === true && verify.body.checksumMatches === true && verify.body.counts?.journalEntries > 0, verify.body);
const download = await api('GET', `${W}/backups/${backupId}/download`, owner);
check('download returns the exact encrypted file with no-store headers', download.status === 200 && download.raw.equals(fileBytes) && download.headers.get('cache-control') === 'private, no-store' && /\.tsmbak"/.test(download.headers.get('content-disposition') ?? ''), { status: download.status, len: download.raw.length });

// --- Permissions -------------------------------------------------------------------
const adminCreate = await api('POST', `${W}/backups`, admin);
check('ADMIN can create a backup', adminCreate.status === 201, adminCreate.body);
const adminRestore = await api('POST', `${W}/backups/${backupId}/restore`, admin);
check('ADMIN cannot restore (OWNER only) 403', adminRestore.status === 403, adminRestore.status);
const adminDelete = await api('DELETE', `${W}/backups/${adminCreate.body.id}`, admin);
check('ADMIN cannot delete a backup 403', adminDelete.status === 403, adminDelete.status);
const outsider = await api('GET', `${W}/backups`, intruder);
check('non-member cannot list backups 403', outsider.status === 403, outsider.status);
const outsiderDl = await api('GET', `${W}/backups/${backupId}/download`, intruder);
check('non-member cannot download a backup 403', outsiderDl.status === 403, outsiderDl.status);

// --- Integrity: tampered / foreign files are refused -----------------------------------
const tampered = Buffer.from(fileBytes); tampered[tampered.length - 10] ^= 0xff;
const tamperedRestore = await api('POST', '/backups/restore-file', owner, fileForm(tampered, 'x.tsmbak'));
check('tampered backup file refused before restore (400 damaged/modified)', tamperedRestore.status === 400 && /damaged|modified/i.test(JSON.stringify(tamperedRestore.body)), tamperedRestore.body);
const notBackup = await api('POST', '/backups/restore-file', owner, fileForm(Buffer.from('%PDF-1.4 hello world, definitely not a backup'), 'x.pdf'));
check('non-backup file refused 400', notBackup.status === 400 && /not a Tangent backup/i.test(JSON.stringify(notBackup.body)), notBackup.body);
const leaked = await api('POST', '/backups/restore-file', intruder, fileForm(fileBytes, 'leaked.tsmbak'));
check('someone who is not the source owner cannot restore a leaked file 403', leaked.status === 403, leaked.body);
const adminFile = await api('POST', '/backups/restore-file', admin, fileForm(fileBytes, 'b.tsmbak'));
check('an ADMIN of the source workspace cannot restore from file either 403', adminFile.status === 403, adminFile.body);

// --- Restore into a NEW workspace --------------------------------------------------------
const restored = await api('POST', `${W}/backups/${backupId}/restore`, owner);
check('restore creates a new workspace owned by the restorer', restored.status === 201 && /\(restored \d{4}-\d{2}-\d{2}\)$/.test(restored.body.workspace?.name ?? '') && restored.body.workspace.id !== ws.id && restored.body.workspace.myRole === 'OWNER', restored.body);
const RW = `/workspaces/${restored.body.workspace?.id}`;
const after = await snapshot(RW, owner);
check('restored trial balance identical (balanced, same totals)', after.trial.isBalanced === true && after.trial.totalDebit === before.trial.totalDebit && after.trial.totalCredit === before.trial.totalCredit, { before: [before.trial.totalDebit, before.trial.totalCredit], after: [after.trial.totalDebit, after.trial.totalCredit] });
check('restored profit & loss identical', after.pnl.totalIncome === before.pnl.totalIncome && after.pnl.totalExpense === before.pnl.totalExpense, { before: [before.pnl.totalIncome, before.pnl.totalExpense], after: [after.pnl.totalIncome, after.pnl.totalExpense] });
check('restored animals and land (same tags, same canonical areas)', JSON.stringify(after.animals.map((a) => a.tagNumber).sort()) === JSON.stringify(before.animals.map((a) => a.tagNumber).sort()) && JSON.stringify(after.land.map((l) => l.areaSqFt).sort()) === JSON.stringify(before.land.map((l) => l.areaSqFt).sort()), null);
check('restored rows have NEW ids (no id shared with the original)', after.animals.every((a) => !before.animals.some((b) => b.id === a.id)), null);

const kidBefore = before.animals.find((a) => a.acquisition === 'BORN_ON_FARM' && a.tagNumber.startsWith('K1-'));
if (kidBefore) {
  const kidAfterRow = after.animals.find((a) => a.tagNumber === kidBefore.tagNumber);
  const [origDetail, newDetail] = await Promise.all([api('GET', `${W}/animals/${kidBefore.id}`, owner), api('GET', `${RW}/animals/${kidAfterRow.id}`, owner)]);
  check('pedigree remapped: restored kid points at the restored dam, not the original', newDetail.body.dam?.tagNumber === origDetail.body.dam?.tagNumber && newDetail.body.dam?.id !== origDetail.body.dam?.id && after.animals.some((a) => a.id === newDetail.body.dam?.id), { orig: origDetail.body.dam, now: newDetail.body.dam });
}
const docBefore = before.docs[0];
if (docBefore) {
  const docAfter = after.docs.find((d) => d.sha256 === docBefore.sha256 && d.title === docBefore.title);
  const [a, b] = await Promise.all([api('GET', `${W}/attachments/${docBefore.id}/download`, owner), api('GET', `${RW}/attachments/${docAfter?.id}/download`, owner)]);
  check('restored document downloads byte-identical to the original', a.status === 200 && b.status === 200 && a.raw.equals(b.raw), { a: a.status, b: b.status });
}
const original = await snapshot(W, owner);
check('original workspace unchanged by the restore', original.animals.length === before.animals.length && original.trial.totalDebit === before.trial.totalDebit && original.docs.length === before.docs.length, null);
const restoreNote = (await api('GET', `/notifications?unread=true&workspaceId=${restored.body.workspace?.id}`, owner)).body;
check('owner notified that the backup was restored', Array.isArray(restoreNote) && restoreNote.some((n) => n.title === 'Backup restored'), restoreNote);

const fromFile = await api('POST', '/backups/restore-file', owner, fileForm(fileBytes, 'b.tsmbak'));
check('owner can restore from the downloaded file too', fromFile.status === 201 && fromFile.body.workspace?.id && fromFile.body.counts?.animals === before.animals.length, fromFile.body);

// --- Failure path: a missing document file makes the backup fail loudly -------------------
const failDoc = after.docs[0];
if (failDoc) {
  const rows = (await api('GET', `${RW}/attachments`, owner)).body;
  // Find the restored file on disk by elimination: newest .bin under the restored workspace folder.
  const { readdirSync, statSync } = await import('node:fs');
  const dir = join(STORAGE, restored.body.workspace.id);
  const files = readdirSync(dir).map((f) => join(dir, f)).sort((x, y) => statSync(y).mtimeMs - statSync(x).mtimeMs);
  unlinkSync(files[0]);
  const failed = await api('POST', `${RW}/backups`, owner);
  const lastStatus = (await api('GET', `${RW}/backups/status`, owner)).body.lastBackup;
  check('backup with a missing document fails (500) and is recorded FAILED with the reason', failed.status === 500 && lastStatus?.status === 'FAILED' && /ENOENT|no such file|integrity/i.test(lastStatus.error ?? ''), { status: failed.status, last: lastStatus });
  const failNote = (await api('GET', `/notifications?unread=true&workspaceId=${restored.body.workspace.id}`, owner)).body;
  check('backup failure raises a CRITICAL notification', failNote.some((n) => n.title === 'Backup failed' && n.severity === 'CRITICAL'), failNote.map((n) => n.title));
  void rows;
}

// --- Settings + scheduled backups with retention ---------------------------------------------
const badRetention = await api('PATCH', `${W}/backups/settings`, owner, { retention: 0 });
check('retention below 1 rejected 400', badRetention.status === 400, badRetention.body);
const settings = await api('PATCH', `${W}/backups/settings`, owner, { retention: 1, autoBackupEnabled: true });
check('settings saved (keep 1 automatic backup)', settings.status === 200 && settings.body.retention === 1, settings.body);

const superToken = await login('superadmin@tangentsmart.test');
const noMfa = await api('POST', '/admin/backups/run-scheduled', superToken);
check('running scheduled backups needs MFA 403', noMfa.status === 403, noMfa.body);
const setup = await api('POST', '/auth/mfa/setup', superToken);
const totp = new OTP({ strategy: 'totp' });
await api('POST', '/auth/mfa/verify-setup', superToken, { code: await totp.generate({ secret: setup.body.secret }) });
const challenge = await api('POST', '/auth/login', null, { email: 'superadmin@tangentsmart.test', password: 'TangentTest12345' });
const mfaLogin = await api('POST', '/auth/mfa/login', null, { mfaToken: challenge.body.mfaToken, code: await totp.generate({ secret: setup.body.secret }) });
const superMfa = mfaLogin.body.accessToken ?? mfaLogin.body.tokens?.accessToken;
const sched1 = await api('POST', '/admin/backups/run-scheduled', superMfa);
const sched2 = await api('POST', '/admin/backups/run-scheduled', superMfa);
check('scheduled run backs up every auto-backup workspace', sched1.status === 201 && sched1.body.completed >= 1 && sched2.status === 201, [sched1.body, sched2.body]);
const scheduledLeft = (await api('GET', `${W}/backups`, owner)).body.filter((b) => b.trigger === 'SCHEDULED');
check('retention keeps only the newest automatic backup', scheduledLeft.length === 1, scheduledLeft.map((b) => b.startedAt));
const manualLeft = (await api('GET', `${W}/backups`, owner)).body.filter((b) => b.trigger === 'MANUAL');
check('manual backups are never pruned automatically', manualLeft.some((b) => b.id === backupId), manualLeft.length);
await api('POST', '/auth/mfa/disable', superMfa, { code: await totp.generate({ secret: setup.body.secret }) });
await api('PATCH', `${W}/backups/settings`, owner, { retention: 7 });

// --- Delete -------------------------------------------------------------------------
const del = await api('DELETE', `${W}/backups/${adminCreate.body.id}`, owner);
const adminFileOnDisk = join(STORAGE, 'backups', ws.id, `${adminCreate.body.id}.tsmbak`);
check('owner deletes a backup; its file is removed from storage', del.status === 200 && !existsSync(adminFileOnDisk), del.body);

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }
