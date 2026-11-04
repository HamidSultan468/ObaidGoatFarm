// Live E2E for Phase 06 (Goat Farm) + the ledger tenant-isolation fix.
// Usage (backend running, local test accounts exist): node scripts/e2e/farm.e2e.mjs http://localhost:3000
const BASE = process.argv[2] ?? 'http://localhost:3002';
const run = Date.now().toString(36);
let passed = 0;
const failures = [];

async function api(method, path, token, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, body: json };
}

function check(name, condition, detail) {
  if (condition) { passed++; console.log('PASS', name); }
  else { failures.push(name); console.log('FAIL', name, JSON.stringify(detail)?.slice(0, 400)); }
}

async function login(email, password) {
  let r = await api('POST', '/auth/login', null, { email, password });
  if (r.status >= 400) {
    await api('POST', '/auth/register', null, { email, password, fullName: email.split('@')[0] });
    r = await api('POST', '/auth/login', null, { email, password });
  }
  return r.body.accessToken ?? r.body.tokens?.accessToken;
}

const owner = await login('owner@tangentsmart.test', 'TangentTest12345');
const intruder = await login('intruder@tangentsmart.test', 'TangentTest12345');
check('login owner + intruder', owner && intruder, { owner: !!owner, intruder: !!intruder });

const workspaces = (await api('GET', '/workspaces', owner)).body;
const ws = (Array.isArray(workspaces) ? workspaces : workspaces.workspaces ?? [])
  .map((w) => w.workspace ?? w).find((w) => w.name === 'Obaid Goat Farm');
check('owner workspace found', !!ws, workspaces);
const W = `/workspaces/${ws.id}`;

// --- Animals --------------------------------------------------------------
const buck = await api('POST', `${W}/animals`, owner, { tagNumber: `B-${run}`, name: 'Sultan', sex: 'MALE', breed: 'Beetal', dateOfBirth: '2024-02-10' });
check('create buck 201', buck.status === 201, buck);
const doe = await api('POST', `${W}/animals`, owner, { tagNumber: `D-${run}`, name: 'Rani', sex: 'FEMALE', breed: 'Beetal', acquisition: 'PURCHASED', acquisitionDate: '2025-06-01' });
check('create doe 201', doe.status === 201, doe);

const dupTag = await api('POST', `${W}/animals`, owner, { tagNumber: `B-${run}`, sex: 'MALE' });
check('duplicate tag 409', dupTag.status === 409, dupTag);
const badSire = await api('POST', `${W}/animals`, owner, { tagNumber: `X-${run}`, sex: 'MALE', sireId: doe.body.id });
check('female as sire rejected 400', badSire.status === 400, badSire);
const badField = await api('POST', `${W}/animals`, owner, { tagNumber: `Y-${run}`, sex: 'MALE', price: 5 });
check('unknown field rejected 400', badField.status === 400, badField);
const selfParent = await api('PATCH', `${W}/animals/${buck.body.id}`, owner, { sireId: buck.body.id });
check('self-parent rejected 400', selfParent.status === 400, selfParent);

const search = await api('GET', `${W}/animals?search=rani`, owner);
check('search by name finds doe', search.status === 200 && search.body.some((a) => a.id === doe.body.id), search);

// --- Health + weights -----------------------------------------------------
const vacc = await api('POST', `${W}/animals/${doe.body.id}/health-records`, owner, {
  type: 'VACCINATION', recordDate: '2026-11-01', description: 'PPR vaccine', medication: 'PPR', nextDueDate: '2026-11-20',
});
check('add vaccination 201', vacc.status === 201, vacc);
const badDue = await api('POST', `${W}/animals/${doe.body.id}/health-records`, owner, {
  type: 'DEWORMING', recordDate: '2026-11-01', description: 'x', nextDueDate: '2026-10-01',
});
check('nextDueDate before recordDate rejected 400', badDue.status === 400, badDue);

const w1 = await api('POST', `${W}/animals/${doe.body.id}/weights`, owner, { recordDate: '2026-10-01', weightKg: '31.250' });
const w2 = await api('POST', `${W}/animals/${doe.body.id}/weights`, owner, { recordDate: '2026-11-01', weightKg: '33.5' });
check('add two weights 201', w1.status === 201 && w2.status === 201, [w1, w2]);
const floatWeight = await api('POST', `${W}/animals/${doe.body.id}/weights`, owner, { recordDate: '2026-11-02', weightKg: 33.5 });
check('numeric (float) weight rejected 400', floatWeight.status === 400, floatWeight);
const zeroWeight = await api('POST', `${W}/animals/${doe.body.id}/weights`, owner, { recordDate: '2026-11-02', weightKg: '0.000' });
check('zero weight rejected 400', zeroWeight.status === 400, zeroWeight);
const weights = await api('GET', `${W}/animals/${doe.body.id}/weights`, owner);
check('weights stored exactly', weights.body.map((w) => w.weightKg).join(',') === '31.25,33.5', weights.body.map((w) => w.weightKg));

// --- Breeding + kidding ---------------------------------------------------
const breeding = await api('POST', `${W}/breeding`, owner, { damId: doe.body.id, sireId: buck.body.id, matingDate: '2026-06-01' });
check('create breeding 201', breeding.status === 201, breeding);
check('expected kidding = mating + 150d', breeding.body.expectedKiddingDate?.startsWith('2026-10-29'), breeding.body.expectedKiddingDate);
const second = await api('POST', `${W}/breeding`, owner, { damId: doe.body.id, matingDate: '2026-06-05' });
check('second open breeding for same dam 409', second.status === 409, second);
const badTransition = await api('PATCH', `${W}/breeding/${breeding.body.id}/status`, owner, { status: 'KIDDED' });
check('manual KIDDED rejected 400', badTransition.status === 400, badTransition);
const pregnant = await api('PATCH', `${W}/breeding/${breeding.body.id}/status`, owner, { status: 'PREGNANT' });
check('mark pregnant 200', pregnant.status === 200 && pregnant.body.status === 'PREGNANT', pregnant);

const overview1 = await api('GET', `${W}/farm/overview`, owner);
check('overview: pregnant>=1, vaccination due listed, kidding upcoming',
  overview1.body.pregnant >= 1
  && overview1.body.dueHealth.some((d) => d.id === vacc.body.id)
  && overview1.body.upcomingKiddings.some((k) => k.id === breeding.body.id), overview1.body);

const tooMany = await api('POST', `${W}/breeding/${breeding.body.id}/kidding`, owner, {
  kiddingDate: '2026-10-30', kidsBorn: 1, kids: [{ tagNumber: `K1-${run}`, sex: 'FEMALE' }, { tagNumber: `K2-${run}`, sex: 'MALE' }],
});
check('more kids than born rejected 400', tooMany.status === 400, tooMany);
const clash = await api('POST', `${W}/breeding/${breeding.body.id}/kidding`, owner, {
  kiddingDate: '2026-10-30', kidsBorn: 2, kids: [{ tagNumber: `B-${run}`, sex: 'FEMALE' }],
});
check('kid tag clash 409 (nothing written)', clash.status === 409, clash);
const kidding = await api('POST', `${W}/breeding/${breeding.body.id}/kidding`, owner, {
  kiddingDate: '2026-10-30', kidsBorn: 3, kids: [{ tagNumber: `K1-${run}`, sex: 'FEMALE' }, { tagNumber: `K2-${run}`, sex: 'MALE' }],
  complications: 'One stillborn',
});
check('record kidding 201 with 2 kids', kidding.status === 201 && kidding.body.kids.length === 2 && kidding.body.breedingRecord.status === 'KIDDED', kidding);
const kid = kidding.body.kids?.[0];
check('kid has dam/sire, BORN_ON_FARM, breed inherited',
  kid && kid.damId === doe.body.id && kid.sireId === buck.body.id && kid.acquisition === 'BORN_ON_FARM' && kid.breed === 'Beetal', kid);
const doeDetail = await api('GET', `${W}/animals/${doe.body.id}`, owner);
check('doe detail lists 2 offspring + latest weight 33.5', doeDetail.body.offspring?.length === 2 && doeDetail.body.weightRecords?.[0]?.weightKg === '33.5', doeDetail.body);
const kiddedAgain = await api('POST', `${W}/breeding/${breeding.body.id}/kidding`, owner, { kiddingDate: '2026-10-31', kidsBorn: 0, kids: [] });
check('kidding a KIDDED record rejected 400', kiddedAgain.status === 400, kiddedAgain);

// --- Ledger tagging + profitability ---------------------------------------
const accounts = (await api('GET', `${W}/accounts`, owner)).body;
const cash = accounts.find((a) => a.code === '1000');
const sales = accounts.find((a) => a.code === '4000');
const expenseAcc = accounts.find((a) => a.code === '5000');
const sale = await api('POST', `${W}/transactions/income`, owner, { toAccountId: cash.id, incomeAccountId: sales.id, amount: '45000.00', memo: 'Sold buck', animalId: buck.body.id });
const vet = await api('POST', `${W}/transactions/expense`, owner, { fromAccountId: cash.id, expenseAccountId: expenseAcc.id, amount: '1500.50', memo: 'Vet visit', animalId: buck.body.id });
check('income + expense tagged with animal 201', sale.status === 201 && vet.status === 201, [sale, vet]);
const floatAmount = await api('POST', `${W}/transactions/income`, owner, { toAccountId: cash.id, incomeAccountId: sales.id, amount: 100.5 });
check('numeric (float) money amount rejected 400', floatAmount.status === 400, floatAmount);
const ledger1 = await api('GET', `${W}/animals/${buck.body.id}/ledger`, owner);
check('animal P&L: 45000 - 1500.50 = 43499.50', ledger1.body.income === '45000.0000' && ledger1.body.expense === '1500.5000' && ledger1.body.net === '43499.5000', ledger1.body);
await api('POST', `${W}/transactions/${vet.body.id}/reverse`, owner);
const ledger2 = await api('GET', `${W}/animals/${buck.body.id}/ledger`, owner);
check('reversal keeps animal tag and cancels the expense', ledger2.body.expense === '0.0000' && ledger2.body.net === '45000.0000', ledger2.body);

const exit = await api('POST', `${W}/animals/${buck.body.id}/exit`, owner, { status: 'SOLD', exitDate: '2026-11-04', exitReason: 'Sold at Eid market' });
check('mark buck SOLD 201', exit.status === 201 && exit.body.status === 'SOLD', exit);
const exitAgain = await api('POST', `${W}/animals/${buck.body.id}/exit`, owner, { status: 'DECEASED', exitDate: '2026-11-04' });
check('second exit rejected 400', exitAgain.status === 400, exitAgain);
const activeList = await api('GET', `${W}/animals`, owner);
check('sold buck hidden from default (ACTIVE) list', !activeList.body.some((a) => a.id === buck.body.id), activeList.body.length);

// --- Tenant isolation -----------------------------------------------------
const intruderWs = await api('POST', '/workspaces', intruder, { name: `Intruder Farm ${run}` });
const IW = `/workspaces/${intruderWs.body.id ?? intruderWs.body.workspace?.id}`;
check('intruder has own workspace', intruderWs.status === 201, intruderWs);
const peek = await api('GET', `${W}/animals/${doe.body.id}`, intruder);
check('intruder reading owner animal 403', peek.status === 403, peek);
const intruderAccounts = (await api('GET', `${IW}/accounts`, intruder)).body;
const iCash = intruderAccounts.find((a) => a.code === '1000');
const crossAccount = await api('POST', `${IW}/transactions/income`, intruder, { toAccountId: iCash.id, incomeAccountId: sales.id, amount: '1.00' });
check('LEDGER FIX: posting to another tenant\'s account 400', crossAccount.status === 400, crossAccount);
const iSales = intruderAccounts.find((a) => a.code === '4000');
const crossAnimal = await api('POST', `${IW}/transactions/income`, intruder, { toAccountId: iCash.id, incomeAccountId: iSales.id, amount: '1.00', animalId: doe.body.id });
check('LEDGER FIX: tagging another tenant\'s animal 400', crossAnimal.status === 400, crossAnimal);
const crossParent = await api('POST', `${IW}/animals`, intruder, { tagNumber: `I-${run}`, sex: 'FEMALE', damId: doe.body.id });
check('cross-tenant dam rejected 400', crossParent.status === 400, crossParent);
const crossBreeding = await api('PATCH', `${IW}/breeding/${breeding.body.id}/status`, intruder, { status: 'ABORTED' });
check('cross-tenant breeding record 404', crossBreeding.status === 404, crossBreeding);

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }
