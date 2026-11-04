// Live E2E for Phase 12 (reports & exports) and Phase 13 server side
// (idempotency keys, If-Match conflict detection).
// Usage: node scripts/e2e/reports-sync.e2e.mjs http://localhost:3000
import { randomUUID } from 'node:crypto';
import { inflateRawSync } from 'node:zlib';

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
  let json; try { json = JSON.parse(raw.toString('utf8')); } catch { json = null; }
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
// Reports use Pakistan calendar days, so "today" must be Pakistan's date too.
const pkDate = (d) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Karachi', year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
const today = pkDate(new Date());
const daysAgo = (n) => pkDate(new Date(Date.now() - n * 86400000));

const owner = await login('owner@tangentsmart.test');
const admin = await login('admin@tangentsmart.test');
const staff = await login('staff@tangentsmart.test');
const intruder = await login('intruder@tangentsmart.test');
const ws = (await api('GET', '/workspaces', owner)).body.find((w) => w.name === 'Obaid Goat Farm');
const W = `/workspaces/${ws.id}`;
const invite = await api('POST', `${W}/members`, owner, { email: 'staff@tangentsmart.test', role: 'STAFF' });
check('setup: staff test user is a STAFF member', [201, 409].includes(invite.status), invite.body);
const accounts = (await api('GET', `${W}/accounts`, owner)).body;
const cash = accounts.find((a) => a.code === '1000');
const sales = accounts.find((a) => a.code === '4000');
const expense = accounts.find((a) => a.code === '5000');

// --- Access per role ------------------------------------------------------------
const ownerList = (await api('GET', `${W}/analytics`, owner)).body;
const staffList = (await api('GET', `${W}/analytics`, staff)).body;
check('owner sees all 8 reports', ownerList.length === 8, ownerList);
check('staff sees only farm reports', JSON.stringify(staffList.sort()) === JSON.stringify(['animal-growth', 'farm-performance']), staffList);
const staffFinance = await api('GET', `${W}/analytics/financial-summary`, staff);
const staffPnl = await api('GET', `${W}/reports/profit-and-loss`, staff);
const staffAudit = await api('GET', `${W}/analytics/audit-log`, staff);
check('staff cannot open financial reports (new analytics AND existing P&L) 403', staffFinance.status === 403 && staffPnl.status === 403, [staffFinance.status, staffPnl.status]);
check('staff cannot open the audit log 403', staffAudit.status === 403, staffAudit.status);
const adminAudit = await api('GET', `${W}/analytics/audit-log`, admin);
check('admin can open the audit log', adminAudit.status === 200, adminAudit.status);
const outsider = await api('GET', `${W}/analytics/farm-performance`, intruder);
check('non-member cannot open any report 403', outsider.status === 403, outsider.status);

// --- Validation -------------------------------------------------------------------
check('unknown report 400', (await api('GET', `${W}/analytics/salaries`, owner)).status === 400, null);
check('reversed date range 400', (await api('GET', `${W}/analytics/financial-summary?from=2026-12-01&to=2026-11-01`, owner)).status === 400, null);
check('unknown export format 400', (await api('GET', `${W}/analytics/financial-summary/export?format=docx`, owner)).status === 400, null);

// --- Inclusive end date (fix) -------------------------------------------------------
const before = (await api('GET', `${W}/reports/profit-and-loss?from=${today}&to=${today}`, owner)).body.totalIncome;
await api('POST', `${W}/transactions/income`, owner, { toAccountId: cash.id, incomeAccountId: sales.id, amount: '1234.56', memo: `Report test ${run}` });
const after = (await api('GET', `${W}/reports/profit-and-loss?from=${today}&to=${today}`, owner)).body.totalIncome;
check('P&L "to=today" now includes today\'s entries (+1234.56)', (Number(after) * 100 - Number(before) * 100).toFixed(0) === '123456', { before, after });

// --- Financial summary / balance sheet / trial balance -------------------------------
const range = `from=2000-01-01&to=${today}`;
const fin = (await api('GET', `${W}/analytics/financial-summary?${range}`, owner)).body;
const pnl = (await api('GET', `${W}/reports/profit-and-loss?${range}`, owner)).body;
const trendIncome = fin.data.trend.reduce((s, t) => s + BigInt(t.income.replace('.', '')), 0n);
check('financial summary matches the P&L endpoint exactly', fin.data.profitAndLoss.totalIncome === pnl.totalIncome && fin.data.profitAndLoss.netProfit === pnl.netProfit, [fin.data.profitAndLoss.totalIncome, pnl.totalIncome]);
check('monthly trend sums to total income (exact)', trendIncome === BigInt(pnl.totalIncome.replace('.', '')), { trendIncome: String(trendIncome), total: pnl.totalIncome });
check('document has summary, trend and category sections', fin.document.sections.map((s) => s.title).join('|') === 'Summary|Monthly trend|Income by category|Expenses by category', fin.document.sections.map((s) => s.title));
const bs = (await api('GET', `${W}/analytics/balance-sheet?asOf=${today}`, owner)).body;
check('balance sheet balances (assets = liabilities + equity + earnings, difference 0)', bs.data.balanced === true && bs.data.difference === '0.0000', bs.data);
const tb = (await api('GET', `${W}/analytics/trial-balance`, owner)).body;
check('trial balance report is balanced', tb.data.isBalanced === true && tb.data.totalDebit === tb.data.totalCredit, tb.data.totalDebit);

// --- Farm ----------------------------------------------------------------------------
const animal = (await api('POST', `${W}/animals`, owner, { tagNumber: `GR-${run}`, sex: 'FEMALE', name: 'Growth test' })).body;
await api('POST', `${W}/animals/${animal.id}/weights`, owner, { recordDate: daysAgo(31), weightKg: '30.000' });
await api('POST', `${W}/animals/${animal.id}/weights`, owner, { recordDate: today, weightKg: '34.650' });
const growth = (await api('GET', `${W}/analytics/animal-growth?from=${daysAgo(40)}&to=${today}`, owner)).body;
const row = growth.data.animals.find((a) => a.tagNumber === `GR-${run}`);
check('growth: 30.000 -> 34.650 kg over 31 days = 150.0 g/day', row?.gainKg === '4.650' && row?.days === 31 && row?.adg === '150.0', row);
const farmOwner = (await api('GET', `${W}/analytics/farm-performance?${range}`, owner)).body;
const farmStaff = (await api('GET', `${W}/analytics/farm-performance?${range}`, staff)).body;
const activeCount = (await api('GET', `${W}/animals?status=ACTIVE`, owner)).body.length;
check('farm performance: herd count matches the animal list', farmOwner.data.herd.activeNow === activeCount, [farmOwner.data.herd.activeNow, activeCount]);
check('farm performance: kidding totals and survival % are consistent', farmOwner.data.kidding.kidsAlive <= farmOwner.data.kidding.kidsBorn && (farmOwner.data.kidding.kidsBorn === 0 || farmOwner.data.kidding.survivalPercent !== null), farmOwner.data.kidding);
check('profit by animal shown to the owner, hidden from staff', farmOwner.document.sections.some((s) => s.title === 'Profit by animal') && !farmStaff.document.sections.some((s) => s.title === 'Profit by animal') && farmStaff.data.profitability.length === 0, null);

// --- Land ------------------------------------------------------------------------------
const land = (await api('GET', `${W}/analytics/land?from=2000-01-01&to=2100-01-01`, owner)).body;
const landProfit = (await api('GET', `${W}/land/reports/profitability`, owner)).body;
check('land report totals match the land profitability endpoint', land.data.total.net === landProfit.total.net && land.data.total.income === landProfit.total.income, [land.data.total, landProfit.total]);

// --- Exports -----------------------------------------------------------------------------
const csv = await api('GET', `${W}/analytics/financial-summary/export?format=csv&${range}`, owner);
const csvText = csv.raw.toString('utf8');
check('CSV export: UTF-8 BOM, attachment, exact totals', csv.status === 200 && csvText.startsWith('﻿') && /attachment; filename="financial-summary-.*\.csv"/.test(csv.headers.get('content-disposition')) && csvText.includes(`Net profit,${roundTo2(pnl.netProfit)}`), csvText.slice(0, 200));
const xlsx = await api('GET', `${W}/analytics/financial-summary/export?format=xlsx&${range}`, owner);
const sheet = xlsx.status === 200 ? unzipEntry(xlsx.raw, 'xl/worksheets/sheet1.xml') : '';
check('Excel export: valid workbook with the summary sheet and exact money values', xlsx.status === 200 && xlsx.headers.get('content-type').includes('spreadsheetml') && sheet.includes(`<v>${roundTo2(pnl.totalIncome)}</v>`), { status: xlsx.status });
const pdf = await api('GET', `${W}/analytics/farm-performance/export?format=pdf&${range}`, owner);
check('PDF export: a real PDF document', pdf.status === 200 && pdf.raw.subarray(0, 5).toString() === '%PDF-' && pdf.headers.get('content-type') === 'application/pdf', { status: pdf.status, len: pdf.raw.length });
const staffExport = await api('GET', `${W}/analytics/financial-summary/export?format=csv`, staff);
check('staff cannot export financial reports 403', staffExport.status === 403, staffExport.status);
const audit = (await api('GET', `${W}/analytics/audit-log?from=${today}&to=${today}&action=report.export`, owner)).body;
check('exports are recorded in the audit log', audit.data.entries.some((e) => e.action === 'report.export'), audit.data.count);
const ops = (await api('GET', `${W}/analytics/operations?${range}`, owner)).body;
check('operations report counts posted entries', ops.data.metrics.find((m) => m.metric === 'Entries posted')?.value > 0, ops.data.metrics.slice(0, 3));

// --- Idempotency (offline outbox retries) --------------------------------------------------
const key = randomUUID();
const body = { toAccountId: cash.id, incomeAccountId: sales.id, amount: '777.70', memo: `Idempotent ${run}` };
const first = await api('POST', `${W}/transactions/income`, owner, body, { 'idempotency-key': key });
const replay = await api('POST', `${W}/transactions/income`, owner, body, { 'idempotency-key': key });
check('retry with the same key returns the SAME entry (201, Idempotent-Replayed)', first.status === 201 && replay.status === 201 && replay.body.id === first.body.id && replay.headers.get('idempotent-replayed') === 'true', [first.status, replay.status, replay.headers.get('idempotent-replayed')]);
const differentBody = await api('POST', `${W}/transactions/income`, owner, { ...body, amount: '777.71' }, { 'idempotency-key': key });
check('same key with a different amount is rejected 422', differentBody.status === 422, differentBody.body);
const raceKey = randomUUID();
const raceBody = { fromAccountId: cash.id, expenseAccountId: expense.id, amount: '55.55', memo: `Race ${run}` };
const race = await Promise.all([1, 2, 3, 4, 5].map(() => api('POST', `${W}/transactions/expense`, owner, raceBody, { 'idempotency-key': raceKey })));
await new Promise((r) => setTimeout(r, 500));
const raceReplay = await api('POST', `${W}/transactions/expense`, owner, raceBody, { 'idempotency-key': raceKey });
const recent = (await api('GET', `${W}/transactions?limit=200`, owner)).body;
const raceEntries = recent.filter((e) => e.memo === `Race ${run}`);
check('five simultaneous submissions with one key post exactly one entry', raceEntries.length === 1 && race.every((r) => r.status === 201 || r.status === 409) && raceReplay.body?.id === raceEntries[0]?.id, { statuses: race.map((r) => r.status), entries: raceEntries.length });
check('original + replay posted only once', recent.filter((e) => e.memo === `Idempotent ${run}`).length === 1, null);
const badKey = await api('POST', `${W}/transactions/income`, owner, body, { 'idempotency-key': 'bad key!' });
check('malformed Idempotency-Key rejected 400', badKey.status === 400, badKey.body);
const failKey = randomUUID();
const failed = await api('POST', `${W}/transactions/income`, owner, { ...body, amount: 'abc' }, { 'idempotency-key': failKey });
const corrected = await api('POST', `${W}/transactions/income`, owner, { ...body, memo: `Corrected ${run}` }, { 'idempotency-key': failKey });
check('a failed request does not burn its key (corrected retry succeeds)', failed.status === 400 && corrected.status === 201, [failed.status, corrected.status]);
const iws = (await api('GET', '/workspaces', intruder)).body[0];
const iAcc = (await api('GET', `/workspaces/${iws.id}/accounts`, intruder)).body;
const otherUser = await api('POST', `/workspaces/${iws.id}/transactions/income`, intruder, { toAccountId: iAcc.find((a) => a.code === '1000').id, incomeAccountId: iAcc.find((a) => a.code === '4000').id, amount: '1.00' }, { 'idempotency-key': key });
check('keys are per user (another user\'s same key is independent)', otherUser.status === 201 && otherUser.body.id !== first.body.id && otherUser.headers.get('idempotent-replayed') === null, otherUser.status);

// --- Conflicting updates (If-Match) ----------------------------------------------------------
const a0 = (await api('GET', `${W}/animals/${animal.id}`, owner)).body;
const edit1 = await api('PATCH', `${W}/animals/${animal.id}`, owner, { name: 'Edited online' }, { 'if-match': `"${a0.updatedAt}"` });
const stale = await api('PATCH', `${W}/animals/${animal.id}`, owner, { name: 'Stale offline edit' }, { 'if-match': `"${a0.updatedAt}"` });
const a2 = (await api('GET', `${W}/animals/${animal.id}`, owner)).body;
check('edit with the current version succeeds', edit1.status === 200, edit1.body);
check('edit based on an old version is refused 412 and does not overwrite', stale.status === 412 && a2.name === 'Edited online', { status: stale.status, name: a2.name });
const parcel = (await api('POST', `${W}/land`, owner, { name: `Sync plot ${run}`, areaValue: '4', areaUnit: 'KANAL' })).body;
const p1 = await api('PATCH', `${W}/land/${parcel.id}`, owner, { landUse: 'Wheat' }, { 'if-match': parcel.updatedAt });
const pStale = await api('PATCH', `${W}/land/${parcel.id}`, owner, { landUse: 'Maize' }, { 'if-match': parcel.updatedAt });
check('land: stale edit refused 412, current edit kept', p1.status === 200 && pStale.status === 412 && (await api('GET', `${W}/land/${parcel.id}`, owner)).body.landUse === 'Wheat', [p1.status, pStale.status]);

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }

function roundTo2(value) {
  const [w, f = ''] = value.replace('-', '').split('.');
  const scaled = BigInt(w + (f + '000').slice(0, 3));
  const r = (scaled + 5n) / 10n;
  const s = r.toString().padStart(3, '0');
  return `${value.startsWith('-') && r !== 0n ? '-' : ''}${s.slice(0, -2)}.${s.slice(-2)}`;
}
function unzipEntry(buffer, name) {
  let offset = 0;
  while (buffer.readUInt32LE(offset) === 0x04034b50) {
    const size = buffer.readUInt32LE(offset + 18);
    const nameLength = buffer.readUInt16LE(offset + 26);
    const extra = buffer.readUInt16LE(offset + 28);
    const entry = buffer.subarray(offset + 30, offset + 30 + nameLength).toString('utf8');
    const start = offset + 30 + nameLength + extra;
    if (entry === name) return inflateRawSync(buffer.subarray(start, start + size)).toString('utf8');
    offset = start + size;
  }
  return '';
}
