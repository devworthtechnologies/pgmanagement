// Fat-finger guard for the payment amount field.
//
// A mistyped amount is trivial to catch at entry and genuinely painful to unwind
// afterwards — it needs a manager to void and re-enter, and until someone
// notices, the dashboard and the guest's balance are both wrong. So we compare
// what's being entered against the guest's own monthly rent and ask for a
// confirmation when it's wildly out of proportion.
//
// It CONFIRMS, never blocks: part payments, advances, deposits and settling
// several months at once are all legitimate and all fall outside the band.

import { formatINR } from './format';

// An amount more than 3× rent, or less than a third of it, is worth a second
// look. Wide enough that a normal part payment (half the rent, say) passes
// without nagging.
export const SANITY_FACTOR = 3;

/**
 * Returns null when the amount is in proportion, or when there's nothing to
 * compare it against (no guest selected, rent unknown, amount not yet valid).
 * Otherwise { ratio, direction: 'high' | 'low' }.
 */
export function checkAmountAgainstRent(amount, monthlyRent) {
  const amt = Number(amount);
  const rent = Number(monthlyRent);

  if (!Number.isFinite(amt) || amt <= 0) return null;
  if (!Number.isFinite(rent) || rent <= 0) return null;

  const ratio = amt / rent;
  if (ratio > SANITY_FACTOR) return { ratio, direction: 'high' };
  if (ratio < 1 / SANITY_FACTOR) return { ratio, direction: 'low' };
  return null;
}

/**
 * The sentence shown in the confirm dialog, e.g.
 *   "₹25,000 is 10× Guest 2's monthly rent of ₹2,500. Record anyway?"
 * Returns null when there's nothing to warn about, so callers can use it as the
 * check itself.
 */
export function describeAmountAnomaly(amount, monthlyRent, guestName) {
  const anomaly = checkAmountAgainstRent(amount, monthlyRent);
  if (!anomaly) return null;

  const who = guestName ? `${guestName}'s` : 'the guest’s';
  const rentText = `${who} monthly rent of ${formatINR(monthlyRent)}`;

  if (anomaly.direction === 'high') {
    return `${formatINR(amount)} is ${Math.round(anomaly.ratio)}× ${rentText}. Record anyway?`;
  }
  return `${formatINR(amount)} is about 1/${Math.round(1 / anomaly.ratio)} of ${rentText}. Record anyway?`;
}
