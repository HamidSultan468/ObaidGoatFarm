import { describe, expect, it } from 'vitest';
import { EXTRACTION_SCHEMA, buildSystemPrompt, normalizeAmount, toDraftProposal, todayIn, type Extraction, type ExtractionContext } from './extraction.js';

const context: ExtractionContext = {
  today: '2026-11-04',
  accounts: [
    { id: 'cash', code: '1000', name: 'Cash', type: 'ASSET', kind: 'CASH' },
    { id: 'bank', code: '1010', name: 'Bank Account', type: 'ASSET', kind: 'BANK' },
    { id: 'ar', code: '1200', name: 'Accounts Receivable', type: 'ASSET', kind: 'RECEIVABLE' },
    { id: 'sales', code: '4000', name: 'Sales Income', type: 'INCOME', kind: 'GENERAL' },
    { id: 'expense', code: '5000', name: 'General Expense', type: 'EXPENSE', kind: 'GENERAL' },
  ],
  animals: [{ id: 'a1', tagNumber: 'B-12', name: 'Sultan' }],
  landParcels: [{ id: 'p1', name: 'North Field' }],
  contacts: [{ id: 'c1', name: 'Haji Aslam' }],
};

const extraction = (kind: Extraction['kind'], fields: Extraction['fields'], warnings: string[] = []): Extraction => ({
  kind,
  summary: 'Sold 2 goats for 90,000 cash',
  confidence: 'high',
  warnings,
  fields,
});

describe('toDraftProposal', () => {
  it('builds an income draft with valid ids and a cleaned amount', () => {
    const result = toDraftProposal(extraction('INCOME', { amount: '90,000', cashAccountId: 'cash', categoryAccountId: 'sales', animalId: 'a1', contactId: 'c1' }), context);
    expect(result).toMatchObject({
      ok: true,
      kind: 'INCOME',
      payload: { amount: '90000', toAccountId: 'cash', incomeAccountId: 'sales', animalId: 'a1', contactId: 'c1', landParcelId: null },
      warnings: [],
    });
  });

  it('drops invented ids and wrong account types with warnings (never trusts the model)', () => {
    const result = toDraftProposal(
      extraction('EXPENSE', { amount: '1500', cashAccountId: 'ar', categoryAccountId: 'sales', animalId: 'ghost-id', landParcelId: 'p1' }),
      context,
    );
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.payload).toMatchObject({ fromAccountId: null, expenseAccountId: null, animalId: null, landParcelId: 'p1', amount: '1500' });
    expect(result.warnings.join(' | ')).toMatch(/not a cash or bank account.*not an expense account.*unknown animal/);
  });

  it('flags a missing or invalid amount instead of guessing', () => {
    for (const amount of [null, 'ninety', '0', '-50', '12.34567']) {
      const result = toDraftProposal(extraction('EXPENSE', { amount, cashAccountId: 'cash', categoryAccountId: 'expense' }), context);
      expect(result.ok && result.payload.amount).toBe(null);
      expect(result.ok && result.warnings).toContain('Amount is missing or unclear');
    }
  });

  it('builds a health draft, defaulting the date to today and the type to OTHER', () => {
    const result = toDraftProposal(extraction('ANIMAL_HEALTH', { animalId: 'a1', healthType: 'NOT_A_TYPE', description: 'Limping', recordDate: null, nextDueDate: '05/12/2026' }), context);
    expect(result).toMatchObject({ ok: true, payload: { animalId: 'a1', type: 'OTHER', recordDate: '2026-11-04', description: 'Limping', nextDueDate: null } });
    expect(result.ok && result.warnings).toContain('Ignored an invalid next due date');
  });

  it('builds a weight draft and strips "kg"', () => {
    const result = toDraftProposal(extraction('ANIMAL_WEIGHT', { animalId: 'a1', weightKg: '32.5 kg', recordDate: '2026-11-03' }), context);
    expect(result).toMatchObject({ ok: true, payload: { animalId: 'a1', weightKg: '32.5', recordDate: '2026-11-03' } });
  });

  it('returns a reason for UNKNOWN instead of a draft', () => {
    expect(toDraftProposal({ ...extraction('UNKNOWN', {}), summary: 'Just a greeting' }, context)).toEqual({ ok: false, reason: 'Just a greeting' });
  });
});

describe('helpers', () => {
  it('normalizeAmount keeps exact decimals', () => {
    expect(normalizeAmount('Rs. 1,250.50')).toBe('1250.50');
    expect(normalizeAmount('PKR 45000')).toBe('45000');
    expect(normalizeAmount('1e5')).toBeNull();
  });

  it('todayIn uses the workspace time zone', () => {
    // 20:30 UTC on Nov 4 is already Nov 5 in Karachi (UTC+5).
    expect(todayIn('Asia/Karachi', new Date('2026-11-04T20:30:00Z'))).toBe('2026-11-05');
  });

  it('schema closes every object and requires every field', () => {
    expect(EXTRACTION_SCHEMA.additionalProperties).toBe(false);
    expect(EXTRACTION_SCHEMA.properties.fields.additionalProperties).toBe(false);
    expect(EXTRACTION_SCHEMA.properties.fields.required).toHaveLength(Object.keys(EXTRACTION_SCHEMA.properties.fields.properties).length);
  });

  it('system prompt lists real ids and today', () => {
    const prompt = buildSystemPrompt(context);
    expect(prompt).toContain('Today is 2026-11-04');
    expect(prompt).toContain('a1 | tag B-12 | Sultan');
    expect(prompt).toContain('Never invent an id');
  });
});
