import type { DraftKind } from '@prisma/client';

/** What the model sees about the workspace, so it can pick real ids instead of inventing them. */
export interface ExtractionContext {
  today: string; // YYYY-MM-DD in the workspace's time zone
  accounts: Array<{ id: string; code: string; name: string; type: string; kind: string }>;
  animals: Array<{ id: string; tagNumber: string; name: string | null }>;
  landParcels: Array<{ id: string; name: string }>;
  contacts: Array<{ id: string; name: string }>;
}

export const HEALTH_TYPES = ['CHECKUP', 'ILLNESS', 'TREATMENT', 'VACCINATION', 'DEWORMING', 'MEDICATION', 'INJURY', 'OTHER'] as const;

const nullableString = { anyOf: [{ type: 'string' }, { type: 'null' }] };
const FIELD_KEYS = [
  'amount',
  'cashAccountId',
  'categoryAccountId',
  'contactId',
  'animalId',
  'landParcelId',
  'memo',
  'healthType',
  'recordDate',
  'description',
  'medication',
  'dosage',
  'veterinarian',
  'nextDueDate',
  'weightKg',
] as const;

/** Structured-output schema: every object closed, every key required (null when unknown). */
export const EXTRACTION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['kind', 'summary', 'confidence', 'warnings', 'fields'],
  properties: {
    kind: { type: 'string', enum: ['INCOME', 'EXPENSE', 'ANIMAL_HEALTH', 'ANIMAL_WEIGHT', 'UNKNOWN'] },
    summary: { type: 'string' },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    warnings: { type: 'array', items: { type: 'string' } },
    fields: {
      type: 'object',
      additionalProperties: false,
      required: [...FIELD_KEYS],
      properties: Object.fromEntries(
        FIELD_KEYS.map((key) => [
          key,
          key === 'healthType' ? { anyOf: [{ type: 'string', enum: [...HEALTH_TYPES] }, { type: 'null' }] } : nullableString,
        ]),
      ),
    },
  },
} as const;

export function buildSystemPrompt(context: ExtractionContext): string {
  const accounts = context.accounts.map((a) => `${a.id} | ${a.code} ${a.name} | ${a.type}/${a.kind}`).join('\n');
  const animals = context.animals.map((a) => `${a.id} | tag ${a.tagNumber}${a.name ? ` | ${a.name}` : ''}`).join('\n');
  const land = context.landParcels.map((p) => `${p.id} | ${p.name}`).join('\n');
  const contacts = context.contacts.map((c) => `${c.id} | ${c.name}`).join('\n');
  return `You turn one short message from a farm or household into a DRAFT record for a finance and goat-farm app. A person reviews every draft before anything is saved.

The message may be in English, Urdu, or Roman Urdu (e.g. "2 bakriyan 90 hazar me bechi, paise cash me aaye"). Today is ${context.today}.

Choose exactly one kind:
- INCOME: money received (sales of animals, milk, crops; rent received).
- EXPENSE: money paid (feed/chara, medicine, vet, labor, fuel, fertilizer).
- ANIMAL_HEALTH: a vaccination, deworming, treatment, checkup, illness or injury of one animal.
- ANIMAL_WEIGHT: an animal's weight in kilograms.
- UNKNOWN: anything else, or too unclear to draft. Explain in summary.

Rules:
- Use ONLY ids from the lists below. Never invent an id. If nothing fits, use null and add a warning.
- cashAccountId = where money went in (INCOME) or came from (EXPENSE): an ASSET account of kind CASH or BANK. If the message doesn't say, prefer the Cash account and add a warning.
- categoryAccountId = an INCOME account for INCOME, an EXPENSE account for EXPENSE.
- amount: a plain decimal string without commas or currency, e.g. "90000" or "1250.50". "hazar" = thousand, "lakh" = 100000.
- Dates as YYYY-MM-DD; "kal" or "yesterday" means the day before today. Default recordDate to today.
- weightKg: decimal string in kilograms, at most 3 decimals.
- summary: one short English sentence describing the draft.
- Set every field that doesn't apply to null. Put anything uncertain in warnings.

Accounts (id | code name | type/kind):
${accounts || '(none)'}

Animals (id | tag | name):
${animals || '(none)'}

Land parcels (id | name):
${land || '(none)'}

Customers / suppliers (id | name):
${contacts || '(none)'}`;
}

export interface Extraction {
  kind: DraftKind | 'UNKNOWN';
  summary: string;
  confidence: 'high' | 'medium' | 'low';
  warnings: string[];
  fields: Partial<Record<(typeof FIELD_KEYS)[number], string | null>>;
}

export type DraftProposal =
  | { ok: true; kind: DraftKind; summary: string; payload: Record<string, unknown>; warnings: string[] }
  | { ok: false; reason: string };

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const AMOUNT = /^\d{1,14}(\.\d{1,4})?$/;
const WEIGHT = /^\d{1,4}(\.\d{1,3})?$/;

/** "45,000 Rs" -> "45000". Returns null if what remains isn't a positive decimal. */
export function normalizeAmount(raw: string | null | undefined, pattern = AMOUNT): string | null {
  if (!raw) return null;
  const cleaned = raw.replace(/[,\s]|rs\.?|pkr|kg/gi, '');
  if (!pattern.test(cleaned) || /^0+(\.0+)?$/.test(cleaned)) return null;
  return cleaned;
}

/**
 * Turns the model's structured output into a draft payload, keeping only
 * ids that exist in this workspace AND have the right account type. Bad or
 * missing values become null with a warning; the reviewer fills them in.
 * Never trusts the model for anything that reaches the database.
 */
export function toDraftProposal(extraction: Extraction, context: ExtractionContext): DraftProposal {
  if (extraction.kind === 'UNKNOWN') {
    return { ok: false, reason: extraction.summary || 'The message could not be understood as a record.' };
  }
  const f = extraction.fields ?? {};
  const warnings = [...(extraction.warnings ?? [])].slice(0, 10).map((w) => String(w).slice(0, 200));
  const summary = String(extraction.summary || '').slice(0, 300) || 'Draft record';
  const account = (id: string | null | undefined) => context.accounts.find((a) => a.id === id);
  const pick = <T extends { id: string }>(list: T[], id: string | null | undefined, label: string): string | null => {
    if (!id) return null;
    if (list.some((item) => item.id === id)) return id;
    warnings.push(`Ignored an unknown ${label}`);
    return null;
  };
  const date = (value: string | null | undefined, fallback: string | null, label: string) => {
    if (!value) return fallback;
    if (DATE.test(value)) return value;
    warnings.push(`Ignored an invalid ${label}`);
    return fallback;
  };

  if (extraction.kind === 'INCOME' || extraction.kind === 'EXPENSE') {
    const isIncome = extraction.kind === 'INCOME';
    const amount = normalizeAmount(f.amount);
    if (!amount) warnings.push('Amount is missing or unclear');
    const cash = account(f.cashAccountId);
    const cashOk = cash && cash.type === 'ASSET' && (cash.kind === 'CASH' || cash.kind === 'BANK');
    if (f.cashAccountId && !cashOk) warnings.push('Ignored an account that is not a cash or bank account');
    if (!f.cashAccountId) warnings.push(isIncome ? 'Choose where the money was received' : 'Choose where the money was paid from');
    const category = account(f.categoryAccountId);
    const categoryOk = category && category.type === (isIncome ? 'INCOME' : 'EXPENSE');
    if (f.categoryAccountId && !categoryOk) warnings.push(`Ignored a category that is not an ${isIncome ? 'income' : 'expense'} account`);
    if (!f.categoryAccountId) warnings.push('Choose a category');
    const base = {
      amount,
      memo: f.memo ? String(f.memo).slice(0, 500) : null,
      contactId: pick(context.contacts, f.contactId, 'customer/supplier'),
      animalId: pick(context.animals, f.animalId, 'animal'),
      landParcelId: pick(context.landParcels, f.landParcelId, 'land parcel'),
    };
    const payload = isIncome
      ? { ...base, toAccountId: cashOk ? cash.id : null, incomeAccountId: categoryOk ? category.id : null }
      : { ...base, fromAccountId: cashOk ? cash.id : null, expenseAccountId: categoryOk ? category.id : null };
    return { ok: true, kind: extraction.kind, summary, payload, warnings };
  }

  if (extraction.kind === 'ANIMAL_HEALTH') {
    const animalId = pick(context.animals, f.animalId, 'animal');
    if (!animalId) warnings.push('Choose the animal');
    const type = f.healthType && (HEALTH_TYPES as readonly string[]).includes(f.healthType) ? f.healthType : 'OTHER';
    return {
      ok: true,
      kind: 'ANIMAL_HEALTH',
      summary,
      warnings,
      payload: {
        animalId,
        type,
        recordDate: date(f.recordDate, context.today, 'record date'),
        description: (f.description || summary).slice(0, 1000),
        medication: f.medication ? f.medication.slice(0, 150) : null,
        dosage: f.dosage ? f.dosage.slice(0, 100) : null,
        veterinarian: f.veterinarian ? f.veterinarian.slice(0, 120) : null,
        nextDueDate: date(f.nextDueDate, null, 'next due date'),
      },
    };
  }

  // ANIMAL_WEIGHT
  const animalId = pick(context.animals, f.animalId, 'animal');
  if (!animalId) warnings.push('Choose the animal');
  const weightKg = normalizeAmount(f.weightKg, WEIGHT);
  if (!weightKg) warnings.push('Weight is missing or unclear');
  return {
    ok: true,
    kind: 'ANIMAL_WEIGHT',
    summary,
    warnings,
    payload: { animalId, weightKg, recordDate: date(f.recordDate, context.today, 'record date') },
  };
}

/** YYYY-MM-DD for "now" in a time zone. */
export function todayIn(timeZone: string, now = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
}
