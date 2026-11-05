// Live E2E for the animal profile photo feature (Phase 06 + Phase 08).
// Usage (backend running): node scripts/e2e/animal-photo.e2e.mjs http://localhost:3000
const BASE = process.argv[2] ?? 'http://localhost:3000';
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
const form = (fields, content, name, type = 'image/png') => {
  const f = new FormData();
  for (const [k, v] of Object.entries(fields)) f.append(k, v);
  if (content) f.append('file', new Blob([content], { type }), name);
  return f;
};

const owner = await login('owner@tangentsmart.test');
const workspaces = (await api('GET', '/workspaces', owner)).body;
const ws = (Array.isArray(workspaces) ? workspaces : workspaces.workspaces ?? []).map((w) => w.workspace ?? w).find((w) => w.name === 'Obaid Goat Farm');
const W = `/workspaces/${ws.id}`;

// A minimal valid 1x1 PNG.
const png = Buffer.from(
  '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c6364000000050001a5f645400000000049454e44ae426082',
  'hex',
);

const animal = await api('POST', `${W}/animals`, owner, { tagNumber: `PHOTO-${run}`, sex: 'FEMALE' });
check('create animal 201', animal.status === 201, animal.body);
const animalId = animal.body.id;

const upload = await api('POST', `${W}/attachments`, owner, form({ module: 'ANIMAL', recordId: animalId, title: 'Profile photo' }, png, 'goat.png'));
check('upload photo attachment 201', upload.status === 201, upload.body);

const setPhoto = await api('PATCH', `${W}/animals/${animalId}`, owner, { photoAttachmentId: upload.body.id });
check('PATCH animal sets photoAttachmentId', setPhoto.status === 200 && setPhoto.body.photoAttachmentId === upload.body.id, setPhoto.body);

const fetched = await api('GET', `${W}/animals/${animalId}`, owner);
check('GET animal returns photoAttachmentId', fetched.body.photoAttachmentId === upload.body.id, fetched.body.photoAttachmentId);

const dl = await api('GET', `${W}/attachments/${upload.body.id}/download`, owner);
check('photo downloads as the original bytes', dl.status === 200 && dl.raw.equals(png), dl.status);

// Another animal's attachment must not be settable as this animal's photo.
const otherAnimal = await api('POST', `${W}/animals`, owner, { tagNumber: `PHOTO-OTHER-${run}`, sex: 'MALE' });
const otherUpload = await api('POST', `${W}/attachments`, owner, form({ module: 'ANIMAL', recordId: otherAnimal.body.id }, png, 'other.png'));
const crossSet = await api('PATCH', `${W}/animals/${animalId}`, owner, { photoAttachmentId: otherUpload.body.id });
check('setting another animal\'s attachment as photo rejected 400', crossSet.status === 400, crossSet.body);

// A GENERAL (untagged) attachment must not be settable either.
const generalUpload = await api('POST', `${W}/attachments`, owner, form({ module: 'GENERAL' }, png, 'general.png'));
const generalSet = await api('PATCH', `${W}/animals/${animalId}`, owner, { photoAttachmentId: generalUpload.body.id });
check('setting a GENERAL attachment as photo rejected 400', generalSet.status === 400, generalSet.body);

// Clearing the photo (null) is allowed.
const clear = await api('PATCH', `${W}/animals/${animalId}`, owner, { photoAttachmentId: null });
check('clearing photoAttachmentId (null) succeeds', clear.status === 200 && clear.body.photoAttachmentId === null, clear.body);

// Deleting the photo attachment nulls the animal's reference (onDelete: SetNull), never blocking the delete.
const setAgain = await api('PATCH', `${W}/animals/${animalId}`, owner, { photoAttachmentId: upload.body.id });
check('re-set photoAttachmentId succeeds', setAgain.status === 200, setAgain.body);
const delAttachment = await api('DELETE', `${W}/attachments/${upload.body.id}`, owner);
check('delete the photo attachment 200', delAttachment.status === 200, delAttachment.body);
const afterDelete = await api('GET', `${W}/animals/${animalId}`, owner);
check('animal.photoAttachmentId nulled after attachment delete', afterDelete.body.photoAttachmentId === null, afterDelete.body.photoAttachmentId);

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.log('Failures:', failures); process.exit(1); }
