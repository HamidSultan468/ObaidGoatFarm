// Live E2E for Phase 09 (Notifications).
// Needs: backend started with SMTP_HOST=127.0.0.1 SMTP_PORT=<sink port>, and
// smtp-sink.mjs running with rejectPattern "intruder".
// Usage: node scripts/e2e/notifications.e2e.mjs http://localhost:3000 <sinkLogFile>
import { existsSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const BASE = process.argv[2] ?? 'http://localhost:3000';
const SINK_LOG = process.argv[3];
const require = createRequire(import.meta.url);
const { OTP } = require('otplib');
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
  let json;
  try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, body: json };
}
function check(name, condition, detail) {
  if (condition) { passed++; console.log('PASS', name); }
  else { failures.push(name); console.log('FAIL', name, JSON.stringify(detail)?.slice(0, 500)); }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const isoDay = (offsetDays) => new Date(Date.now() + offsetDays * 86400000).toISOString().slice(0, 10);
const sinkMessages = () => (SINK_LOG && existsSync(SINK_LOG) ? readFileSync(SINK_LOG, 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l)) : []);

async function login(email) {
  const r = await api('POST', '/auth/login', null, { email, password: 'TangentTest12345' });
  return r.body.accessToken ?? r.body.tokens?.accessToken;
}
const workspaceByName = async (token, name) => {
  const list = (await api('GET', '/workspaces', token)).body;
  return (Array.isArray(list) ? list : list.workspaces ?? []).map((w) => w.workspace ?? w).find((w) => !name || w.name === name);
};

const owner = await login('owner@tangentsmart.test');
const intruder = await login('intruder@tangentsmart.test');
const ws = await workspaceByName(owner, 'Obaid Goat Farm');
const W = `/workspaces/${ws.id}`;
const iws = await workspaceByName(intruder);
const IW = `/workspaces/${iws.id}`;

// Clean slate for this run: read everything so counts below are this run's.
await api('POST', '/notifications/read-all', owner);

// --- Preferences --------------------------------------------------------------
const prefs = await api('GET', '/notifications/preferences', owner);
check('preferences: email channel reported available (SMTP configured)', prefs.status === 200 && prefs.body.channels.email === true, prefs.body.channels);
check('preferences: defaults in-app on, email off', prefs.body.categories.every((c) => typeof c.inApp === 'boolean') && prefs.body.categories.find((c) => c.category === 'FARM_HEALTH')?.inApp === true, prefs.body.categories);
const badTz = await api('PUT', '/notifications/preferences', owner, { timeZone: 'Mars/Olympus' });
check('unknown time zone rejected 400', badTz.status === 400, badTz.body);
const halfQuiet = await api('PUT', '/notifications/preferences', owner, { quietHoursStart: 600, quietHoursEnd: null });
check('half-set quiet hours rejected 400', halfQuiet.status === 400, halfQuiet.body);
const setPrefs = await api('PUT', '/notifications/preferences', owner, {
  timeZone: 'Asia/Karachi', quietHoursStart: null, quietHoursEnd: null,
  categories: [
    { category: 'FARM_HEALTH', inApp: true, email: true },
    { category: 'LAND_LEASE', inApp: true, email: false },
    { category: 'ANNOUNCEMENT', inApp: true, email: true },
  ],
});
check('save preferences (email on for farm health + announcements)', setPrefs.status === 200 && setPrefs.body.categories.find((c) => c.category === 'FARM_HEALTH').email === true, setPrefs.body);

// --- Rules: data that should trigger reminders ---------------------------------
const animal = await api('POST', `${W}/animals`, owner, { tagNumber: `N-${run}`, name: 'Moti', sex: 'FEMALE' });
const health = await api('POST', `${W}/animals/${animal.body.id}/health-records`, owner, {
  type: 'DEWORMING', recordDate: isoDay(-30), description: 'Ivermectin', nextDueDate: isoDay(1),
});
const overdue = await api('POST', `${W}/animals/${animal.body.id}/health-records`, owner, {
  type: 'VACCINATION', recordDate: isoDay(-40), description: 'Enterotoxemia booster', nextDueDate: isoDay(-2),
});
const lease = await api('POST', `${W}/land`, owner, {
  name: `Leased plot ${run}`, areaValue: '8', areaUnit: 'KANAL', tenure: 'LEASED_IN', leaseStartDate: isoDay(-300), leaseEndDate: isoDay(10),
});
check('setup: animal, due + overdue health records, expiring lease', [animal, health, overdue, lease].every((r) => r.status === 201), [animal.status, health.status, overdue.status, lease.status]);

const rules = await api('GET', `${W}/notification-rules`, owner);
check('rules list automatic categories with default roles (no ANNOUNCEMENT)', rules.status === 200 && rules.body.some((r) => r.category === 'FARM_HEALTH') && !rules.body.some((r) => r.category === 'ANNOUNCEMENT'), rules.body);
const badRule = await api('PUT', `${W}/notification-rules`, owner, { rules: [{ category: 'ANNOUNCEMENT', isEnabled: true, recipientRoles: ['OWNER'] }] });
check('ANNOUNCEMENT cannot be an automatic rule 400', badRule.status === 400, badRule.body);
const peekRules = await api('GET', `${W}/notification-rules`, intruder);
check('non-member reading rules 403', peekRules.status === 403, peekRules.status);

const run1 = await api('POST', `${W}/notification-rules/run`, owner);
check('run rules creates reminders', run1.status === 201 && run1.body.created >= 3, run1.body);
const run2 = await api('POST', `${W}/notification-rules/run`, owner);
check('running again creates nothing new (dedupe)', run2.status === 201 && run2.body.created === 0, run2.body);

const inbox = (await api('GET', `/notifications?unread=true&workspaceId=${ws.id}`, owner)).body;
const dueNote = inbox.find((n) => n.title.includes(`N-${run}`) && n.title.startsWith('Deworming due'));
const overdueNote = inbox.find((n) => n.title.includes(`N-${run}`) && n.title.startsWith('Vaccination overdue'));
const leaseNote = inbox.find((n) => n.title === `Lease ending soon: Leased plot ${run}`);
check('inbox: deworming due (INFO) linking to the animal', dueNote?.severity === 'INFO' && dueNote?.link === `/goat-farm/animals/${animal.body.id}`, dueNote);
check('inbox: vaccination overdue escalated as WARNING', overdueNote?.severity === 'WARNING', overdueNote);
check('inbox: lease ending soon linking to the parcel', leaseNote?.link === `/land/parcels/${lease.body.id}`, leaseNote);

// --- Email delivery -----------------------------------------------------------
await api('POST', `${W}/notification-rules/run`, owner); // drives the delivery worker
await sleep(500);
const deliveries = (await api('GET', `${W}/notifications/deliveries`, owner)).body;
const healthEmails = deliveries.filter((d) => d.notification.title.includes(`N-${run}`));
check('farm-health reminders emailed (SENT), lease reminder not (email off)', healthEmails.length >= 2 && healthEmails.every((d) => d.status === 'SENT') && !deliveries.some((d) => d.notification.title.includes(`Leased plot ${run}`)), healthEmails);
const received = sinkMessages().filter((m) => m.data.includes(`N-${run}`));
check('SMTP server received the reminder emails for the owner', received.length >= 2 && received.every((m) => m.to.some((t) => t.includes('owner@tangentsmart.test'))), received.map((m) => m.to));

// --- Read state ------------------------------------------------------------------
const before = (await api('GET', `/notifications/unread-count?workspaceId=${ws.id}`, owner)).body.count;
const markOne = await api('POST', `/notifications/${dueNote.id}/read`, owner);
const after = (await api('GET', `/notifications/unread-count?workspaceId=${ws.id}`, owner)).body.count;
check('mark one read decrements the unread count', markOne.status === 201 && after === before - 1, { before, after });
const stealRead = await api('POST', `/notifications/${overdueNote.id}/read`, intruder);
check('another user cannot touch my notification (404)', stealRead.status === 404, stealRead.body);

// --- Manual sending -----------------------------------------------------------------
const empty = await api('POST', `${W}/notifications/send`, owner, { title: 'x', body: 'y' });
check('manual send with no recipients 400', empty.status === 400, empty.body);
const intruderId = (await api('GET', '/auth/me', intruder)).body.id ?? (await api('GET', '/auth/me', intruder)).body.user?.id;
const outsider = await api('POST', `${W}/notifications/send`, owner, { title: 'x', body: 'y', userIds: [intruderId] });
check('manual send to a non-member 400', outsider.status === 400, outsider.body);
const sendBlocked = await api('POST', `${W}/notifications/send`, intruder, { title: 'x', body: 'y', roles: ['OWNER'] });
check('non-member cannot send in my workspace 403', sendBlocked.status === 403, sendBlocked.status);
const manual = await api('POST', `${W}/notifications/send`, owner, { title: `Vet visit Friday ${run}`, body: 'All goats in the shed by 9am.', roles: ['OWNER'], severity: 'WARNING' });
check('manual announcement to OWNER role delivered', manual.status === 201 && manual.body.recipients === 1, manual.body);

// --- Quiet hours defer email ----------------------------------------------------------
const nowKhi = (() => { const p = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Karachi', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(new Date()); return Number(p[0].value) * 60 + Number(p[2].value); })();
await api('PUT', '/notifications/preferences', owner, { quietHoursStart: (nowKhi + 1440 - 30) % 1440, quietHoursEnd: (nowKhi + 60) % 1440 });
await api('POST', `${W}/notifications/send`, owner, { title: `Quiet test ${run}`, body: 'Should wait.', roles: ['OWNER'] });
await api('POST', `${W}/notification-rules/run`, owner);
const quiet = (await api('GET', `${W}/notifications/deliveries`, owner)).body.find((d) => d.notification.title === `Quiet test ${run}`);
check('during quiet hours the email waits (PENDING, scheduled ~60 min later)', quiet?.status === 'PENDING' && new Date(quiet.nextAttemptAt) - Date.now() > 50 * 60000, quiet);
await api('PUT', '/notifications/preferences', owner, { quietHoursStart: null, quietHoursEnd: null });

// --- Retry on SMTP failure (sink rejects "intruder") ------------------------------------
await api('PUT', '/notifications/preferences', intruder, { categories: [{ category: 'ANNOUNCEMENT', inApp: true, email: true }] });
await api('POST', `${IW}/notifications/send`, intruder, { title: `Bounce test ${run}`, body: 'x', roles: ['OWNER'] });
await api('POST', `${IW}/notification-rules/run`, intruder);
const bounce = (await api('GET', `${IW}/notifications/deliveries`, intruder)).body.find((d) => d.notification.title === `Bounce test ${run}`);
check('SMTP rejection is recorded and retried later (PENDING, attempt 1, error kept)', bounce?.status === 'PENDING' && bounce.attempts === 1 && /550|Mailbox/i.test(bounce.lastError ?? '') && new Date(bounce.nextAttemptAt) > new Date(), bounce);
const ownerSeesIntruderLog = (await api('GET', `${IW}/notifications/deliveries`, owner)).status;
check('delivery log is workspace-isolated (403)', ownerSeesIntruderLog === 403, ownerSeesIntruderLog);

// --- Platform announcement (Super Admin Owner + MFA) -------------------------------------
const notAdmin = await api('POST', '/admin/notifications/send', owner, { title: 'x', body: 'y' });
check('regular user cannot send platform announcements 403', notAdmin.status === 403, notAdmin.status);

const superToken = await login('superadmin@tangentsmart.test');
if (superToken) {
  const noMfa = await api('POST', '/admin/notifications/send', superToken, { title: 'x', body: 'y' });
  check('super admin without MFA is refused 403', noMfa.status === 403, noMfa.body);
  const setup = await api('POST', '/auth/mfa/setup', superToken);
  const totp = new OTP({ strategy: 'totp' });
  const code = await totp.generate({ secret: setup.body.secret });
  const verify = await api('POST', '/auth/mfa/verify-setup', superToken, { code });
  const challenge = await api('POST', '/auth/login', null, { email: 'superadmin@tangentsmart.test', password: 'TangentTest12345' });
  const mfaLogin = await api('POST', '/auth/mfa/login', null, { mfaToken: challenge.body.mfaToken, code: await totp.generate({ secret: setup.body.secret }) });
  const mfaToken = mfaLogin.body.accessToken ?? mfaLogin.body.tokens?.accessToken;
  check('super admin enables MFA and logs in with a TOTP code', verify.status === 204 && challenge.body.mfaRequired === true && !!mfaToken, { verify: verify.status, challenge: challenge.body, mfa: mfaLogin.status });
  const platform = await api('POST', '/admin/notifications/send', mfaToken, { title: `Maintenance tonight ${run}`, body: 'The app will be offline 11pm-11:30pm.', severity: 'INFO' });
  check('platform announcement reaches every active user', platform.status === 201 && platform.body.recipients >= 3, platform.body);
  const ownerHasIt = (await api('GET', '/notifications?unread=true', owner)).body.some((n) => n.title === `Maintenance tonight ${run}` && n.workspaceId === null);
  check('owner inbox shows the platform announcement (no workspace)', ownerHasIt, null);
  // Leave the test account as it was: disable MFA again.
  await api('POST', '/auth/mfa/disable', mfaToken, { code: await totp.generate({ secret: setup.body.secret }) });
} else {
  console.log('SKIP platform announcement checks: superadmin@tangentsmart.test does not exist');
}

const markAll = await api('POST', `/notifications/read-all?workspaceId=${ws.id}`, owner);
const zero = (await api('GET', `/notifications/unread-count?workspaceId=${ws.id}`, owner)).body.count;
check('mark all read leaves zero unread', markAll.status === 201 && zero === 0, { markAll: markAll.body, zero });

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }
