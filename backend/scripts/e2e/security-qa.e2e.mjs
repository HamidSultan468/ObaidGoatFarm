// Phase 6 (CLAUDE.md Phase 14 — Security & QA): a consolidated security
// regression across every module at once, plus auth hardening and input
// validation probes not already covered by the per-phase E2E scripts.
// Usage: node scripts/e2e/security-qa.e2e.mjs http://localhost:3000
import { OTP } from 'otplib';

const totp = new OTP({ strategy: 'totp' });

const BASE = process.argv[2] ?? 'http://localhost:3000';
const run = Date.now().toString(36);
let passed = 0;
const failures = [];

async function api(method, path, token, body, headers = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: { ...(body !== undefined ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const raw = Buffer.from(await res.arrayBuffer());
  let json;
  try {
    json = JSON.parse(raw.toString('utf8'));
  } catch {
    json = null;
  }
  return { status: res.status, body: json, raw };
}
function check(name, condition, detail) {
  if (condition) {
    passed++;
    console.log('PASS', name);
  } else {
    failures.push(name);
    console.log('FAIL', name, JSON.stringify(detail)?.slice(0, 600));
  }
}
async function registerAndLogin(email, password = 'TangentTest12345') {
  await api('POST', '/auth/register', null, { email, password, fullName: email.split('@')[0] });
  const r = await api('POST', '/auth/login', null, { email, password });
  return r.body;
}

// --- Setup: two fully independent tenants, no shared data with the other phase scripts ---
const emailA = `secqa-a-${run}@tangentsmart.test`;
const emailB = `secqa-b-${run}@tangentsmart.test`;
const loginA = await registerAndLogin(emailA);
const loginB = await registerAndLogin(emailB);
const tokenA = loginA.accessToken ?? loginA.tokens?.accessToken;
const tokenB = loginB.accessToken ?? loginB.tokens?.accessToken;
const wsA = (await api('POST', '/workspaces', tokenA, { name: `SecQA A ${run}` })).body;
const W = `/workspaces/${wsA.id}`;
check('setup: workspace A created', !!wsA?.id, wsA);

// =========================================================================
// Cross-tenant isolation sweep — every :workspaceId-scoped module, with
// userB's token against workspace A. WorkspaceGuard runs before any
// resource lookup, so no seed data is needed for a base-collection check.
// =========================================================================
const sweep = [
  ['GET', `${W}/accounts`],
  ['GET', `${W}/accounts/nonexistent-id`],
  ['GET', `${W}/accounts/nonexistent-id/balance`],
  ['GET', `${W}/budgets`],
  ['GET', `${W}/contacts`],
  ['GET', `${W}/contacts/nonexistent-id`],
  ['GET', `${W}/recurring-templates`],
  ['GET', `${W}/reports/trial-balance`],
  ['GET', `${W}/reports/profit-and-loss`],
  ['GET', `${W}/transactions`],
  ['GET', `${W}/analytics`],
  ['GET', `${W}/analytics/financial-summary`],
  ['GET', `${W}/animals`],
  ['GET', `${W}/animals/nonexistent-id`],
  ['GET', `${W}/breeding`],
  ['GET', `${W}/farm/overview`],
  ['GET', `${W}/land`],
  ['GET', `${W}/land/nonexistent-id`],
  ['GET', `${W}/attachments`],
  ['GET', `${W}/notification-rules`],
  ['GET', `${W}/backups`],
  ['GET', `${W}/ai/providers`],
  ['GET', `${W}/ai/providers/usage`],
  ['GET', `${W}/drafts`],
  ['GET', `${W}/whatsapp/config`],
  ['GET', `${W}/whatsapp/links`],
  ['GET', `${W}/whatsapp/messages`],
  ['GET', `${W}`], // workspaces.controller GET :workspaceId
];
for (const [method, path] of sweep) {
  const r = await api(method, path, tokenB, undefined);
  check(`tenant isolation: ${method} ${path.replace(W, '/workspaces/:A')} with an outsider token`, r.status === 403, { status: r.status, body: r.body });
}

// Mutating endpoints must be blocked too, not just reads.
const mutateSweep = [
  ['POST', `${W}/contacts`, { type: 'CUSTOMER', name: 'Should not be created' }],
  ['POST', `${W}/animals`, { tag: 'intruder-tag', species: 'GOAT', sex: 'FEMALE' }],
  ['POST', `${W}/land`, { name: 'Intruder plot', area: '1', unit: 'KANAL', tenure: 'OWNED' }],
  ['PATCH', `${W}/contacts/nonexistent-id/status`, { isActive: false }],
];
for (const [method, path, body] of mutateSweep) {
  const r = await api(method, path, tokenB, body);
  check(`tenant isolation (write): ${method} ${path.replace(W, '/workspaces/:A')}`, r.status === 403, { status: r.status, body: r.body });
}
// Confirm the writes above genuinely did not happen (not just a wrong status code).
const contactsAfter = (await api('GET', `${W}/contacts`, tokenA)).body;
check('tenant isolation (write): the blocked contact was never created', !contactsAfter.some((c) => c.name === 'Should not be created'), contactsAfter);

// Non-member entirely outside any workspace (no token at all for this workspace) vs a 404 workspace id.
const randomGuid = '00000000-0000-0000-0000-000000000000';
const rUnknownWs = await api('GET', `/workspaces/${randomGuid}/accounts`, tokenA);
check('a well-formed but nonexistent workspace id is rejected (not a 500)', [403, 404].includes(rUnknownWs.status), rUnknownWs.status);

// =========================================================================
// Auth hardening
// =========================================================================
const meNoToken = await api('GET', '/auth/me', null);
check('no token: 401', meNoToken.status === 401, meNoToken.status);

const meGarbage = await api('GET', '/auth/me', 'not-a-real-jwt');
check('malformed token: 401', meGarbage.status === 401, meGarbage.status);

const tamperedToken = tokenA.slice(0, -4) + (tokenA.slice(-4) === 'aaaa' ? 'bbbb' : 'aaaa');
const meTampered = await api('GET', '/auth/me', tamperedToken);
check('tampered signature: 401', meTampered.status === 401, meTampered.status);

check('a valid token still works (sanity check for the two tests above)', (await api('GET', '/auth/me', tokenA)).status === 200);

// Registration validation, live (not just DTO code review).
const rShortPw = await api('POST', '/auth/register', null, { email: `secqa-shortpw-${run}@tangentsmart.test`, password: 'short12345', fullName: 'x' }); // 10 chars, under the 12-char minimum
check('password under 12 chars is rejected', rShortPw.status === 400, rShortPw.status);
const rDup = await api('POST', '/auth/register', null, { email: emailA, password: 'TangentTest12345', fullName: 'dup' });
check('duplicate email is rejected 409', rDup.status === 409, rDup.status);

// Refresh rotation: single-use.
const refreshToken = loginA.refreshToken ?? loginA.tokens?.refreshToken;
const refresh1 = await api('POST', '/auth/refresh', null, { refreshToken });
check('first refresh succeeds and issues a new pair', refresh1.status === 200 && !!refresh1.body?.accessToken, refresh1.body);
const refresh2 = await api('POST', '/auth/refresh', null, { refreshToken });
check('reusing a spent refresh token is rejected', refresh2.status === 401, refresh2.status);
const freshRefreshToken = refresh1.body.refreshToken;
const freshAccessToken = refresh1.body.accessToken;

// Logout revokes the refresh token.
const logoutRes = await api('POST', '/auth/logout', null, { refreshToken: freshRefreshToken });
check('logout succeeds', logoutRes.status === 204, logoutRes.status);
const refreshAfterLogout = await api('POST', '/auth/refresh', null, { refreshToken: freshRefreshToken });
check('a revoked (logged-out) refresh token can no longer refresh', refreshAfterLogout.status === 401, refreshAfterLogout.status);
// By design (SECURITY.md): the access token itself is a stateless JWT with
// no server-side revocation list, so it keeps working until it naturally
// expires — logout revokes future refreshes, not the current access token.
const meAfterLogout = await api('GET', '/auth/me', freshAccessToken);
check('(documented behavior) the still-unexpired access token keeps working after logout', meAfterLogout.status === 200, meAfterLogout.status);

// MFA: a purpose-scoped challenge token must never work as a normal bearer token.
const mfaEmail = `secqa-mfa-${run}@tangentsmart.test`;
const mfaLogin = await registerAndLogin(mfaEmail);
const mfaUserToken = mfaLogin.accessToken ?? mfaLogin.tokens?.accessToken;
const setup = (await api('POST', '/auth/mfa/setup', mfaUserToken)).body;
const setupCode = await totp.generate({ secret: setup.secret });
const verifySetup = await api('POST', '/auth/mfa/verify-setup', mfaUserToken, { code: setupCode });
check('MFA enrollment completes with a valid TOTP code', verifySetup.status === 204, verifySetup.status);

const mfaChallenge = await api('POST', '/auth/login', null, { email: mfaEmail, password: 'TangentTest12345' });
check('login on an MFA-enabled account returns a challenge, not real tokens', mfaChallenge.body?.mfaRequired === true && !mfaChallenge.body?.accessToken, mfaChallenge.body);
const challengeAsBearer = await api('GET', '/auth/me', mfaChallenge.body.mfaToken);
check('the MFA challenge token is rejected everywhere a real access token would work', challengeAsBearer.status === 401, challengeAsBearer.status);

const rightCode = await totp.generate({ secret: setup.secret });
const wrongCode = String((Number(rightCode) + 1) % 1000000).padStart(6, '0');
const mfaLoginWrong = await api('POST', '/auth/mfa/login', null, { mfaToken: mfaChallenge.body.mfaToken, code: wrongCode });
check('completing MFA login with the wrong code is rejected', mfaLoginWrong.status === 401 || mfaLoginWrong.status === 400, mfaLoginWrong.status);
const mfaLoginRight = await api('POST', '/auth/mfa/login', null, { mfaToken: mfaChallenge.body.mfaToken, code: rightCode });
check('completing MFA login with the correct code succeeds', mfaLoginRight.status === 200 && !!mfaLoginRight.body?.accessToken, mfaLoginRight.body);

const disableWrong = await api('POST', '/auth/mfa/disable', mfaUserToken, { code: '000000' });
check('disabling MFA with a wrong code is rejected (a hijacked session alone cannot turn protection off)', disableWrong.status === 401 || disableWrong.status === 400, disableWrong.status);
const disableRight = await api('POST', '/auth/mfa/disable', mfaUserToken, { code: await totp.generate({ secret: setup.secret }) });
check('disabling MFA with the correct code succeeds', disableRight.status === 204, disableRight.status);

// =========================================================================
// Input validation / injection probes
// =========================================================================
const sqlLikeName = `Robert'); DROP TABLE "Contact"; --`;
const sqlProbe = await api('POST', `${W}/contacts`, tokenA, { type: 'CUSTOMER', name: sqlLikeName });
check('a SQL-injection-shaped name is stored and returned as inert literal text (Prisma is parameterized)', sqlProbe.status === 201 && sqlProbe.body?.name === sqlLikeName, sqlProbe.body);
const contactsStillThere = await api('GET', `${W}/contacts`, tokenA);
check('the probe did not actually run any SQL — the table still responds normally', contactsStillThere.status === 200 && Array.isArray(contactsStillThere.body), contactsStillThere.status);

const scriptLikeName = `<script>alert(document.cookie)</script>`;
const xssProbe = await api('POST', `${W}/contacts`, tokenA, { type: 'CUSTOMER', name: scriptLikeName });
check('a script-tag-shaped name is stored as inert literal text, not interpreted server-side', xssProbe.status === 201 && xssProbe.body?.name === scriptLikeName, xssProbe.body);

const overLong = await api('POST', `${W}/contacts`, tokenA, { type: 'CUSTOMER', name: 'x'.repeat(200) });
check('a name over the documented 150-char limit is rejected 400, not silently truncated', overLong.status === 400, overLong.status);

const extraField = await api('POST', `${W}/contacts`, tokenA, { type: 'CUSTOMER', name: 'Whitelist probe', isAdmin: true });
check('an unexpected extra field is rejected (whitelist + forbidNonWhitelisted), not silently dropped or accepted', extraField.status === 400, extraField.status);

const accountsA = (await api('GET', `${W}/accounts`, tokenA)).body;
const cashAccount = accountsA.find((a) => a.code === '1000');
const salesAccount = accountsA.find((a) => a.code === '4000');
const negIncome = await api('POST', `${W}/transactions/income`, tokenA, { toAccountId: cashAccount.id, incomeAccountId: salesAccount.id, amount: '-500.00' });
check('a negative amount on income is rejected', negIncome.status === 400, negIncome.status);

// =========================================================================
// Rate limiting — last: the global throttle (100 req/min per client) is
// shared across this whole script's requests, so exhausting it here would
// otherwise 429 every check that follows for up to 60s.
// =========================================================================
let sawRateLimited = false;
for (let i = 0; i < 110; i++) {
  const r = await api('POST', '/auth/login', null, { email: 'nobody@tangentsmart.test', password: 'wrong-password' });
  if (r.status === 429) {
    sawRateLimited = true;
    break;
  }
}
check('rate limiting throttles repeated login attempts (429 within 110 tries)', sawRateLimited);

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length > 0) process.exitCode = 1;
