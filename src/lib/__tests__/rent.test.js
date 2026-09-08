import { monthKeyOf, monthKeyToDate, monthLabel, perGuestRent, prevMonthKey } from '../rent';

// Occupancy/balance/dashboard-stat math used to live in rent.js and was
// tested here directly. That logic now lives server-side (Room.status,
// Room.occupied_beds, GET /stats/dashboard) since the app was wired to the
// real backend — so only the calendar-key helpers below are still local,
// pure logic worth unit testing.

describe('month keys', () => {
  it('formats month keys with zero padding', () => {
    expect(monthKeyOf(new Date(2026, 6, 11))).toBe('2026-07');
    expect(monthKeyOf(new Date(2026, 11, 31))).toBe('2026-12');
  });

  it('computes previous month across year boundaries', () => {
    expect(prevMonthKey('2026-07')).toBe('2026-06');
    expect(prevMonthKey('2026-01')).toBe('2025-12');
  });

  it('renders human labels', () => {
    expect(monthLabel('2026-07')).toBe('July 2026');
  });
});

describe('monthKeyToDate', () => {
  it('appends the first-of-month day for the payments API', () => {
    expect(monthKeyToDate('2026-07')).toBe('2026-07-01');
  });
});

describe('perGuestRent', () => {
  it('divides the room rent by capacity, not by occupants', () => {
    expect(perGuestRent(10000, 2)).toBe(5000);
    expect(perGuestRent(10000, 1)).toBe(10000);
    expect(perGuestRent(8000, 4)).toBe(2000);
  });

  it('rounds to whole rupees', () => {
    // 3333.33… — three guests at 3334 add up to 10002. Nobody cares, it's a
    // prefill and staff can override it.
    expect(perGuestRent(10000, 3)).toBe(3333);
    expect(perGuestRent(10000, 6)).toBe(1667);
  });

  it('accepts numeric strings (form fields hand it strings)', () => {
    expect(perGuestRent('10000', '2')).toBe(5000);
  });

  it('returns null when there is no rent to split', () => {
    expect(perGuestRent(null, 2)).toBeNull();
    expect(perGuestRent(undefined, 2)).toBeNull();
    expect(perGuestRent('', 2)).toBeNull();
    expect(perGuestRent('abc', 2)).toBeNull();
    expect(perGuestRent(NaN, 2)).toBeNull();
  });

  it('returns null for a capacity it cannot divide by', () => {
    expect(perGuestRent(10000, 0)).toBeNull();
    expect(perGuestRent(10000, -1)).toBeNull();
    expect(perGuestRent(10000, null)).toBeNull();
    expect(perGuestRent(10000, '')).toBeNull();
  });
});
