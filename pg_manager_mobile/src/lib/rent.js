// Month-key helpers shared across screens.
//
// Occupancy, room status, rent balances and dashboard totals used to be
// computed here client-side against a local guests/rooms/payments array.
// The backend now owns that math (Room.occupied_beds/status are
// server-computed, and GET /properties/{id}/stats/dashboard returns
// pending_rent/collected/occupancy_rate/due_guests pre-calculated) — so
// this file only keeps the pure calendar-key helpers screens still need
// for display and for building `for_month`/`?month=` query values.

import { format } from 'date-fns';

export function monthKeyOf(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

export function monthLabel(monthKey) {
  const [y, m] = String(monthKey).split('-').map(Number);
  if (!y || !m) return String(monthKey);
  return format(new Date(y, m - 1, 1), 'MMMM yyyy');
}

export function prevMonthKey(monthKey = monthKeyOf()) {
  const [y, m] = String(monthKey).split('-').map(Number);
  return monthKeyOf(new Date(y, m - 2, 1));
}

// Payments' `for_month` must be the first-of-month date the DB CHECK
// constraint expects, e.g. "2026-07-01".
export function monthKeyToDate(monthKey) {
  return `${monthKey}-01`;
}

// A room's rent covers the whole room; each guest's share is it split across
// BEDS, not across current occupants. Dividing by occupants would prefill the
// first guest in an empty 2-sharing room ₹10,000 and the second ₹5,000 — two
// people in the same room on different rent for no reason. Capacity keeps the
// number stable no matter who's living there.
//
// Prefill only. guests.monthly_rent is what actually gets billed, and staff can
// override this for a solo occupant who genuinely pays for the whole room.
export function perGuestRent(defaultRent, capacity) {
  if (defaultRent === null || defaultRent === undefined || defaultRent === '') return null;
  const rent = Number(defaultRent);
  const beds = Number(capacity);
  if (!Number.isFinite(rent) || !Number.isFinite(beds) || beds < 1) return null;
  return Math.round(rent / beds);
}
