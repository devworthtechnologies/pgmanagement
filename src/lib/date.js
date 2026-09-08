// Date-only helpers for the guest join date.
//
// Everything here is deliberately string math. `new Date('2026-07-25')` parses
// as UTC midnight, and `new Date().toISOString()` renders in UTC — so in IST
// (UTC+5:30) both shift the calendar day between 00:00 and 05:30 local. That's
// what dated every guest added after midnight to YESTERDAY. A date-only value
// has no timezone; converting it through a Date is what invents one.
//
// Display format is DD/MM/YYYY (Indian convention, what staff type); the wire
// format to/from the API is always ISO YYYY-MM-DD.

const pad2 = (n) => String(n).padStart(2, '0');

const DAYS_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

const isLeapYear = (year) => (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;

function daysInMonth(year, month) {
  if (month === 2 && isLeapYear(year)) return 29;
  return DAYS_IN_MONTH[month - 1];
}

// Today's date in the DEVICE's timezone, as YYYY-MM-DD. Built from the local
// calendar parts — never toISOString().
export function todayLocalISO() {
  const now = new Date();
  return `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())}`;
}

export function firstOfThisMonthISO() {
  const now = new Date();
  return `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-01`;
}

// 'DD/MM/YYYY' -> 'YYYY-MM-DD', or null if it isn't exactly that shape AND a
// real calendar date. Strict on purpose: '1/2/2026' is rejected rather than
// guessed at, and '31/02/2026' is rejected rather than rolled forward into
// March the way Date would.
export function parseDdMmYyyy(str) {
  const match = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(String(str ?? '').trim());
  if (!match) return null;

  const [, dd, mm, yyyy] = match;
  const day = Number(dd);
  const month = Number(mm);
  const year = Number(yyyy);

  if (month < 1 || month > 12) return null;
  if (day < 1 || day > daysInMonth(year, month)) return null;

  return `${yyyy}-${mm}-${dd}`;
}

// 'YYYY-MM-DD' -> 'DD/MM/YYYY', or '' when there's nothing to show. Splits the
// string rather than parsing it, so no timezone can shift the day. Tolerates a
// trailing time part in case the field ever arrives as a full timestamp.
export function formatIsoToDdMmYyyy(iso) {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso ?? ''));
  if (!match) return '';
  const [, yyyy, mm, dd] = match;
  return `${dd}/${mm}/${yyyy}`;
}
