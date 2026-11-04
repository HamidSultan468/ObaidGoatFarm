/** Average goat gestation. Used only to suggest a date; users may override it. */
export const GOAT_GESTATION_DAYS = 150;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Mating date + gestation, computed in UTC so DST never shifts it by a day. */
export function expectedKiddingDate(matingDate: Date, gestationDays = GOAT_GESTATION_DAYS): Date {
  return new Date(matingDate.getTime() + gestationDays * MS_PER_DAY);
}

export type BreedingStatusValue = 'MATED' | 'PREGNANT' | 'NOT_PREGNANT' | 'KIDDED' | 'ABORTED';

/**
 * Allowed manual status changes. KIDDED is reachable only through the
 * kidding endpoint (it creates the kids); NOT_PREGNANT/KIDDED/ABORTED are final.
 */
const MANUAL_TRANSITIONS: Record<BreedingStatusValue, BreedingStatusValue[]> = {
  MATED: ['PREGNANT', 'NOT_PREGNANT', 'ABORTED'],
  PREGNANT: ['ABORTED'],
  NOT_PREGNANT: [],
  KIDDED: [],
  ABORTED: [],
};

export function canTransition(from: BreedingStatusValue, to: BreedingStatusValue): boolean {
  return MANUAL_TRANSITIONS[from].includes(to);
}

export function canRecordKidding(status: BreedingStatusValue): boolean {
  return status === 'MATED' || status === 'PREGNANT';
}
