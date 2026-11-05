// Live E2E for the "Staff" tab: list/role-change/remove workspace members.
// Usage (backend running): node scripts/e2e/workspace-members.e2e.mjs http://localhost:3000
const BASE = process.argv[2] ?? 'http://localhost:3000';
const run = Date.now().toString(36);
let passed = 0;
const failures = [];

async function api(method, path, token, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json;
  try { json = await res.json(); } catch { json = null; }
  return { status: res.status, body: json };
}
function check(name, condition, detail) {
  if (condition) { passed++; console.log('PASS', name); }
  else { failures.push(name); console.log('FAIL', name, JSON.stringify(detail)?.slice(0, 400)); }
}
async function login(email, password = 'TangentTest12345') {
  const r = await api('POST', '/auth/login', null, { email, password });
  return r.body?.accessToken ?? r.body?.tokens?.accessToken;
}

const owner = await login('owner@tangentsmart.test');
const intruder = await login('intruder@tangentsmart.test');
const workspaces = (await api('GET', '/workspaces', owner)).body;
const ws = (Array.isArray(workspaces) ? workspaces : workspaces.workspaces ?? []).map((w) => w.workspace ?? w).find((w) => w.name === 'Obaid Goat Farm');
const W = `/workspaces/${ws.id}`;
const iws = (await api('GET', '/workspaces', intruder)).body;
const IW = `/workspaces/${(Array.isArray(iws) ? iws : iws.workspaces ?? []).map((w) => w.workspace ?? w)[0].id}`;

// --- Register + invite a fresh staff member for this run -------------------
const staffEmail = `staff-${run}@tangentsmart.test`;
const register = await api('POST', '/auth/register', null, { email: staffEmail, password: 'TangentTest12345', fullName: `Staff ${run}` });
check('register new staff user 201', register.status === 201, register.body);

const invite = await api('POST', `${W}/members`, owner, { email: staffEmail, role: 'STAFF' });
check('invite member 201', invite.status === 201, invite.body);

// --- List ------------------------------------------------------------------
const list = await api('GET', `${W}/members`, owner);
check('list members 200', list.status === 200, list.body);
const member = list.body?.find((m) => m.user?.email === staffEmail);
check('new member appears in the list as STAFF', member?.role === 'STAFF', member);

const staffToken = await login(staffEmail);
const listAsStaff = await api('GET', `${W}/members`, staffToken);
check('any active member may view the list', listAsStaff.status === 200, listAsStaff.status);

const listAsIntruder = await api('GET', `${W}/members`, intruder);
check('non-member listing another workspace\'s members 403', listAsIntruder.status === 403, listAsIntruder.status);

// --- Role change -------------------------------------------------------------
const promote = await api('PATCH', `${W}/members/${member.id}/role`, owner, { role: 'MANAGER' });
check('owner promotes STAFF to MANAGER 200', promote.status === 200 && promote.body.role === 'MANAGER', promote.body);

const selfChange = await api('PATCH', `${W}/members/${(list.body.find((m) => m.user?.email === 'owner@tangentsmart.test'))?.id}/role`, owner, { role: 'ADMIN' });
check('owner changing own role rejected 400', selfChange.status === 400, selfChange.body);

const toOwner = await api('PATCH', `${W}/members/${member.id}/role`, owner, { role: 'OWNER' });
check('promoting to OWNER rejected 400 (not an assignable role)', toOwner.status === 400, toOwner.body);

const staffPromote = await api('PATCH', `${W}/members/${member.id}/role`, staffToken, { role: 'ADMIN' });
check('a MANAGER cannot change roles (requires OWNER/ADMIN) 403', staffPromote.status === 403, staffPromote.status);

const ownerMember = list.body.find((m) => m.user?.email === 'owner@tangentsmart.test');
const changeOwnerRole = await api('PATCH', `${W}/members/${ownerMember.id}/role`, owner, { role: 'ADMIN' });
check('changing the OWNER\'s own membership role rejected (403/400)', [400, 403].includes(changeOwnerRole.status), changeOwnerRole.body);

// --- Removal -----------------------------------------------------------------
const removeForeign = await api('DELETE', `${IW}/members/${member.id}`, intruder);
check('removing a member via the wrong workspace 404', removeForeign.status === 404, removeForeign.status);

const remove = await api('DELETE', `${W}/members/${member.id}`, owner);
check('owner removes the member 204', remove.status === 204, remove.status);

const listAfterRemoval = await api('GET', `${W}/members`, owner);
check('removed member no longer appears', !listAfterRemoval.body.some((m) => m.id === member.id), listAfterRemoval.body);

const removedCannotList = await api('GET', `${W}/members`, staffToken);
check('removed member loses access (403)', removedCannotList.status === 403, removedCannotList.status);

const removeOwner = await api('DELETE', `${W}/members/${ownerMember.id}`, owner);
check('removing the OWNER rejected (400/403)', [400, 403].includes(removeOwner.status), removeOwner.body);

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }
