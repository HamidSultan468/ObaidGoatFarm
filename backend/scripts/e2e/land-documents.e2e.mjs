// Live E2E for Phase 07 (Land) + Phase 08 (Documents).
// Usage (backend running): node scripts/e2e/land-documents.e2e.mjs http://localhost:3000 ./storage
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const BASE = process.argv[2] ?? 'http://localhost:3002';
const STORAGE = process.argv[3];
const run = Date.now().toString(36);
let passed = 0;
const failures = [];

async function api(method, path, token, body) {
  const isForm = body instanceof FormData;
  const res = await fetch(BASE + path, {
    method,
    headers: { ...(isForm || !body ? {} : { 'content-type': 'application/json' }), ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: isForm ? body : body ? JSON.stringify(body) : undefined,
  });
  const buf = Buffer.from(await res.arrayBuffer());
  let json;
  try { json = JSON.parse(buf.toString()); } catch { json = buf; }
  return { status: res.status, body: json, headers: res.headers, raw: buf };
}
function check(name, condition, detail) {
  if (condition) { passed++; console.log('PASS', name); }
  else { failures.push(name); console.log('FAIL', name, JSON.stringify(detail)?.slice(0, 400)); }
}
async function login(email) {
  const r = await api('POST', '/auth/login', null, { email, password: 'TangentTest12345' });
  return r.body.accessToken ?? r.body.tokens?.accessToken;
}

const owner = await login('owner@tangentsmart.test');
const intruder = await login('intruder@tangentsmart.test');
const workspaces = (await api('GET', '/workspaces', owner)).body;
const ws = (Array.isArray(workspaces) ? workspaces : workspaces.workspaces ?? []).map((w) => w.workspace ?? w).find((w) => w.name === 'Obaid Goat Farm');
const W = `/workspaces/${ws.id}`;
const iws = (await api('GET', '/workspaces', intruder)).body;
const IW = `/workspaces/${(Array.isArray(iws) ? iws : iws.workspaces ?? []).map((w) => w.workspace ?? w)[0].id}`;

// --- Land ------------------------------------------------------------------
const parcel = await api('POST', `${W}/land`, owner, { name: `North Field ${run}`, location: 'Chak 12, Sargodha', surveyNumber: 'Khasra 145/2', areaValue: '2.5', areaUnit: 'ACRE', landUse: 'Fodder (berseem)' });
check('create parcel 201', parcel.status === 201, parcel);
check('2.5 acre stored as 108900 sq ft', parcel.body.areaSqFt === '108900', parcel.body.areaSqFt);
check('conversions: 20 kanal, 400 marla', parcel.body.areaConversions?.KANAL === '20.0000' && parcel.body.areaConversions?.MARLA === '400.0000', parcel.body.areaConversions);
check('breakdown 2 acre 4 kanal 0 marla', JSON.stringify(parcel.body.areaBreakdown) === JSON.stringify({ acre: 2, kanal: 4, marla: 0, squareFeet: '0.00' }), parcel.body.areaBreakdown);

const zero = await api('POST', `${W}/land`, owner, { name: 'Zero', areaValue: '0', areaUnit: 'KANAL' });
check('zero area rejected 400', zero.status === 400, zero);
const floatArea = await api('POST', `${W}/land`, owner, { name: 'Float', areaValue: 2.5, areaUnit: 'ACRE' });
check('numeric (float) area rejected 400', floatArea.status === 400, floatArea);
const badLease = await api('POST', `${W}/land`, owner, { name: 'Lease', areaValue: '10', areaUnit: 'KANAL', tenure: 'LEASED_IN', leaseStartDate: '2026-06-01', leaseEndDate: '2026-01-01' });
check('lease end before start rejected 400', badLease.status === 400, badLease);
const unitOnly = await api('PATCH', `${W}/land/${parcel.body.id}`, owner, { areaUnit: 'KANAL' });
check('area unit without value rejected 400', unitOnly.status === 400, unitOnly);
const resized = await api('PATCH', `${W}/land/${parcel.body.id}`, owner, { areaValue: '20', areaUnit: 'KANAL' });
check('resize to 20 kanal keeps 108900 sq ft', resized.status === 200 && resized.body.areaSqFt === '108900', resized.body);

const convert = await api('GET', `${W}/land/convert?value=1&unit=HECTARE`, owner);
check('converter: 1 hectare = 19.7684 kanal', convert.status === 200 && convert.body.KANAL === '19.7684', convert.body);

const accounts = (await api('GET', `${W}/accounts`, owner)).body;
const cash = accounts.find((a) => a.code === '1000');
const sales = accounts.find((a) => a.code === '4000');
const expenseAcc = accounts.find((a) => a.code === '5000');
await api('POST', `${W}/transactions/income`, owner, { toAccountId: cash.id, incomeAccountId: sales.id, amount: '180000.00', memo: 'Berseem crop sale', landParcelId: parcel.body.id });
await api('POST', `${W}/transactions/expense`, owner, { fromAccountId: cash.id, expenseAccountId: expenseAcc.id, amount: '35250.75', memo: 'Fertilizer + labor', landParcelId: parcel.body.id });
const ledger = await api('GET', `${W}/land/${parcel.body.id}/ledger`, owner);
check('parcel P&L: 180000 - 35250.75 = 144749.25', ledger.body.income === '180000.0000' && ledger.body.expense === '35250.7500' && ledger.body.net === '144749.2500', ledger.body);
const report = await api('GET', `${W}/land/reports/profitability`, owner);
const row = report.body.rows?.find((r) => r.parcel.id === parcel.body.id);
check('profitability report row matches parcel ledger', row?.net === '144749.2500', report.body);

const peekLand = await api('GET', `${W}/land/${parcel.body.id}`, intruder);
check('intruder reading owner parcel 403', peekLand.status === 403, peekLand);
const iAcc = (await api('GET', `${IW}/accounts`, intruder)).body;
const tagForeign = await api('POST', `${IW}/transactions/income`, intruder, { toAccountId: iAcc.find((a) => a.code === '1000').id, incomeAccountId: iAcc.find((a) => a.code === '4000').id, amount: '1.00', landParcelId: parcel.body.id });
check('tagging another tenant\'s parcel 400', tagForeign.status === 400, tagForeign);

// --- Documents -------------------------------------------------------------
const pdf = Buffer.from(`%PDF-1.4\n% land deed ${run}\n1 0 obj << >> endobj\ntrailer << >>\n%%EOF\n`);
const form = (fields, content, name, type = 'application/pdf') => {
  const f = new FormData();
  for (const [k, v] of Object.entries(fields)) f.append(k, v);
  if (content) f.append('file', new Blob([content], { type }), name);
  return f;
};

const up = await api('POST', `${W}/attachments`, owner, form({ module: 'LAND', recordId: parcel.body.id, title: 'Fard (ownership record)' }, pdf, 'fard.pdf'));
check('upload PDF to parcel 201', up.status === 201, up.body);
check('response hides storageKey, reports sniffed type + sha256', up.body.storageKey === undefined && up.body.mimeType === 'application/pdf' && /^[0-9a-f]{64}$/.test(up.body.sha256), up.body);

const disguised = await api('POST', `${W}/attachments`, owner, form({ module: 'LAND', recordId: parcel.body.id }, Buffer.from('MZ\x90\x00 fake exe'), 'photo.png', 'image/png'));
check('exe renamed to .png rejected 400', disguised.status === 400, disguised.body);
const svg = await api('POST', `${W}/attachments`, owner, form({ module: 'GENERAL' }, Buffer.from('<svg onload="alert(1)">'), 'x.svg', 'image/svg+xml'));
check('SVG (script carrier) rejected 400', svg.status === 400, svg.body);
const noFile = await api('POST', `${W}/attachments`, owner, form({ module: 'GENERAL' }));
check('missing file rejected 400', noFile.status === 400, noFile.body);
const tooBig = await api('POST', `${W}/attachments`, owner, form({ module: 'GENERAL' }, Buffer.concat([Buffer.from('%PDF-'), Buffer.alloc(10 * 1024 * 1024)]), 'big.pdf'));
check('file over 10 MB rejected 413', tooBig.status === 413, tooBig.body);
const noRecord = await api('POST', `${W}/attachments`, owner, form({ module: 'ANIMAL' }, pdf, 'a.pdf'));
check('ANIMAL document without recordId 400', noRecord.status === 400, noRecord.body);
const traversal = await api('POST', `${W}/attachments`, owner, form({ module: 'GENERAL' }, pdf, '../../evil.pdf'));
check('path in filename stripped', traversal.status === 201 && traversal.body.fileName === 'evil.pdf', traversal.body);

const dl = await api('GET', `${W}/attachments/${up.body.id}/download`, owner);
check('download returns the exact original bytes', dl.status === 200 && dl.raw.equals(pdf), { status: dl.status, len: dl.raw.length });
check('download headers: type, attachment disposition, no-store, nosniff',
  dl.headers.get('content-type') === 'application/pdf'
  && dl.headers.get('content-disposition')?.startsWith('attachment; filename="fard.pdf"')
  && dl.headers.get('cache-control') === 'private, no-store'
  && dl.headers.get('x-content-type-options') === 'nosniff', Object.fromEntries(dl.headers));

if (STORAGE) {
  const dir = join(STORAGE, ws.id);
  const files = readdirSync(dir).map((f) => join(dir, f));
  const newest = files.sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  const onDisk = newest.map((f) => readFileSync(f));
  check('file on disk is encrypted (no plaintext PDF bytes)', onDisk.length > 0 && onDisk.every((b) => !b.includes(Buffer.from(`land deed ${run}`)) && !b.subarray(0, 5).equals(Buffer.from('%PDF-'))), newest.slice(0, 2));
}

const list = await api('GET', `${W}/attachments?module=LAND&recordId=${parcel.body.id}`, owner);
check('list by record returns the deed only', list.status === 200 && list.body.length === 1 && list.body[0].id === up.body.id, list.body);

const peekDoc = await api('GET', `${W}/attachments/${up.body.id}/download`, intruder);
check('intruder downloading owner document 403', peekDoc.status === 403, peekDoc.status);
const ownDocWrongWs = await api('GET', `${IW}/attachments/${up.body.id}/download`, intruder);
check('owner document via intruder\'s own workspace 404', ownDocWrongWs.status === 404, ownDocWrongWs.status);
const attachForeign = await api('POST', `${IW}/attachments`, intruder, form({ module: 'LAND', recordId: parcel.body.id }, pdf, 'x.pdf'));
check('attaching to another tenant\'s parcel 400', attachForeign.status === 400, attachForeign.body);

const del = await api('DELETE', `${W}/attachments/${traversal.body.id}`, owner);
const dlDeleted = await api('GET', `${W}/attachments/${traversal.body.id}/download`, owner);
check('delete then download 404', del.status === 200 && dlDeleted.status === 404, [del.body, dlDeleted.status]);

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }
