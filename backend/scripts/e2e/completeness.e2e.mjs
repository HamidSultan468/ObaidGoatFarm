// Live E2E for the "finish what's yours to finish" pass (2026-11-05):
// budgets UI backend, recurring templates UI backend, full animal/land
// profile edit (If-Match), device-metadata-enriched sessions, and bank
// reconciliation. Usage: node scripts/e2e/completeness.e2e.mjs http://localhost:3000
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
  return { status: res.status, body: json };
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
async function login(email, deviceId, deviceName, platform) {
  await api('POST', '/auth/register', null, { email, password: 'TangentTest12345', fullName: email.split('@')[0] });
  const r = await api('POST', '/auth/login', null, { email, password: 'TangentTest12345' }, {
    ...(deviceId ? { 'x-device-id': deviceId } : {}),
    ...(deviceName ? { 'x-device-name': deviceName } : {}),
    ...(platform ? { 'x-device-platform': platform } : {}),
  });
  return r.body.accessToken ?? r.body.tokens?.accessToken;
}

const email = `completeness-${run}@tangentsmart.test`;
const token = await login(email, `device-${run}`, 'Test Phone', 'android');
const ws = (await api('POST', '/workspaces', token, { name: `Completeness ${run}` })).body;
const W = `/workspaces/${ws.id}`;
const accounts = (await api('GET', `${W}/accounts`, token)).body;
const cash = accounts.find((a) => a.code === '1000');
const sales = accounts.find((a) => a.code === '4000');
const expense = accounts.find((a) => a.code === '5000');

// --- Budgets -----------------------------------------------------------------
const budget = await api('POST', `${W}/budgets`, token, { accountId: expense.id, periodStart: '2026-11-01', periodEnd: '2026-11-30', amount: '1000.00' });
check('budget created', budget.status === 201 && budget.body.amount === '1000.0000', budget.body);
const budgetsList = await api('GET', `${W}/budgets`, token);
check('budget list includes the account relation', budgetsList.body[0]?.account?.code === '5000', budgetsList.body);
await api('POST', `${W}/transactions/expense`, token, { fromAccountId: cash.id, expenseAccountId: expense.id, amount: '250.00' });
const progress = await api('GET', `${W}/budgets/${budget.body.id}/progress`, token);
check('budget progress reflects the posted expense', progress.body.actual === '250.0000' && progress.body.percentUsed === '25.00', progress.body);

// --- Recurring templates ------------------------------------------------------
const template = await api('POST', `${W}/recurring-templates`, token, {
  name: 'Monthly rent', entryType: 'EXPENSE', fromAccountId: cash.id, toAccountId: expense.id, amount: '500.00', frequency: 'MONTHLY', nextRunDate: '2026-12-01',
});
check('recurring template created', template.status === 201, template.body);
const ran = await api('POST', `${W}/recurring-templates/${template.body.id}/run-now`, token);
check('run-now posts a balanced entry for the template amount', ran.status === 201 && ran.body.lines?.length === 2, ran.body);
const afterRun = await api('GET', `${W}/recurring-templates`, token);
check('next run date advanced by one month after running', afterRun.body.find((t) => t.id === template.body.id)?.nextRunDate?.startsWith('2027-01-01'), afterRun.body);
const deactivated = await api('PATCH', `${W}/recurring-templates/${template.body.id}/status`, token, { isActive: false });
check('template can be deactivated', deactivated.body.isActive === false, deactivated.body);
const runWhileInactive = await api('POST', `${W}/recurring-templates/${template.body.id}/run-now`, token);
check('an inactive template refuses to run', runWhileInactive.status === 400, runWhileInactive.status);

// --- Full animal profile edit -------------------------------------------------
const animal = await api('POST', `${W}/animals`, token, { tagNumber: `ED-${run}`, sex: 'FEMALE', breed: 'Beetal' });
const edited = await api('PATCH', `${W}/animals/${animal.body.id}`, token, { name: 'Edited name', breed: 'Teddy', color: 'Brown' }, { 'if-match': animal.body.updatedAt });
check('animal profile fields beyond health status are editable', edited.status === 200 && edited.body.name === 'Edited name' && edited.body.breed === 'Teddy', edited.body);
const staleEdit = await api('PATCH', `${W}/animals/${animal.body.id}`, token, { notes: 'stale' }, { 'if-match': animal.body.updatedAt });
check('a stale If-Match on the profile edit is refused 412', staleEdit.status === 412, staleEdit.status);

// --- Full land parcel edit ----------------------------------------------------
const parcel = await api('POST', `${W}/land`, token, { name: 'Edit test plot', areaValue: '5', areaUnit: 'KANAL', tenure: 'OWNED' });
const parcelEdited = await api('PATCH', `${W}/land/${parcel.body.id}`, token, { name: 'Renamed plot', landUse: 'Wheat' }, { 'if-match': parcel.body.updatedAt });
check('land parcel fields beyond status are editable', parcelEdited.status === 200 && parcelEdited.body.name === 'Renamed plot', parcelEdited.body);
const staleParcelEdit = await api('PATCH', `${W}/land/${parcel.body.id}`, token, { notes: 'stale' }, { 'if-match': parcel.body.updatedAt });
check('a stale If-Match on the parcel edit is refused 412', staleParcelEdit.status === 412, staleParcelEdit.status);

// --- Device-metadata-enriched sessions ----------------------------------------
const sessions = await api('GET', '/auth/sessions', token);
const mine = sessions.body.find((s) => s.deviceId === `device-${run}`);
check('a session carries the friendly device name/platform reported at login', mine?.deviceName === 'Test Phone' && mine?.platform === 'android', sessions.body);
const tokenNoDevice = await login(`completeness-nodev-${run}@tangentsmart.test`);
const sessionsNoDevice = await api('GET', '/auth/sessions', tokenNoDevice);
check('a session with no device metadata degrades to null, not an error', sessionsNoDevice.status === 200 && sessionsNoDevice.body[0].deviceName === null, sessionsNoDevice.body);

// --- Bank reconciliation -------------------------------------------------------
const statement = await api('GET', `${W}/accounts/${cash.id}/statement`, token);
check('statement rows carry a line id and start unreconciled', statement.body.rows.length > 0 && statement.body.rows[0].id && statement.body.rows[0].reconciledAt === null, statement.body);
const lineId = statement.body.rows[0].id;
const reconciled = await api('PATCH', `${W}/accounts/${cash.id}/lines/${lineId}/reconcile`, token, { reconciled: true });
check('a line can be marked reconciled', reconciled.status === 200 && reconciled.body.reconciledAt !== null, reconciled.body);
const statementAfter = await api('GET', `${W}/accounts/${cash.id}/statement`, token);
check('the statement reflects the reconciled line afterward', statementAfter.body.rows.find((r) => r.id === lineId)?.reconciledAt !== null, statementAfter.body);
const uncheck = await api('PATCH', `${W}/accounts/${cash.id}/lines/${lineId}/reconcile`, token, { reconciled: false });
check('a line can be un-reconciled', uncheck.body.reconciledAt === null, uncheck.body);
const wrongAccount = await api('PATCH', `${W}/accounts/${sales.id}/lines/${lineId}/reconcile`, token, { reconciled: true });
check('reconciling a line id that belongs to a different account is rejected', wrongAccount.status === 404, wrongAccount.status);

// --- Platform-wide system log viewer (Admin Console) --------------------------
const superAdminEmail = 'superadmin@tangentsmart.test';
const superAdminToken = await login(superAdminEmail);
const notAdmin = await api('GET', '/admin/logs', token); // a regular (non-platform-admin) user
check('a non-platform-admin cannot read the system log', notAdmin.status === 403, notAdmin.status);
const logs = await api('GET', '/admin/logs?limit=5', superAdminToken);
check('the system log returns recent entries across the whole platform, not just one workspace', logs.status === 200 && Array.isArray(logs.body) && logs.body.length > 0, logs.status);
check('a log entry carries the resolved workspace name and actor email, not raw ids', typeof logs.body[0].workspace === 'object' || logs.body[0].workspace === null, logs.body[0]);
const filtered = await api('GET', `/admin/logs?action=accounting.budget.create&limit=50`, superAdminToken);
check('filtering by action only returns matching entries', filtered.body.every((l) => l.action.toLowerCase().includes('accounting.budget.create')), filtered.body);

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length > 0) process.exitCode = 1;
