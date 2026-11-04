import { describe, expect, it } from 'vitest';
import { computeProfitability } from './tagged-profitability.util.js';

const line = (amount: string, type: string) => ({ amount, account: { type } });

describe('computeProfitability', () => {
  it('returns zeros for no entries', () => {
    expect(computeProfitability([])).toEqual({ income: '0.0000', expense: '0.0000', net: '0.0000' });
  });

  it('counts income credits as positive income and ignores the cash side', () => {
    const result = computeProfitability([{ lines: [line('25000', 'ASSET'), line('-25000', 'INCOME')] }]);
    expect(result).toEqual({ income: '25000.0000', expense: '0.0000', net: '25000.0000' });
  });

  it('nets income against expenses exactly, with no float drift', () => {
    const result = computeProfitability([
      { lines: [line('0.1', 'ASSET'), line('-0.1', 'INCOME')] },
      { lines: [line('0.2', 'ASSET'), line('-0.2', 'INCOME')] },
      { lines: [line('0.3', 'EXPENSE'), line('-0.3', 'ASSET')] },
    ]);
    expect(result).toEqual({ income: '0.3000', expense: '0.3000', net: '0.0000' });
  });

  it('cancels a reversed entry', () => {
    const result = computeProfitability([
      { lines: [line('1200', 'EXPENSE'), line('-1200', 'ASSET')] },
      { lines: [line('-1200', 'EXPENSE'), line('1200', 'ASSET')] },
    ]);
    expect(result.expense).toBe('0.0000');
  });

  it('reports a loss as negative net', () => {
    const result = computeProfitability([
      { lines: [line('500', 'ASSET'), line('-500', 'INCOME')] },
      { lines: [line('800', 'EXPENSE'), line('-800', 'LIABILITY')] },
    ]);
    expect(result.net).toBe('-300.0000');
  });
});
