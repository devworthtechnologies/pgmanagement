import { firstOfThisMonthISO, formatIsoToDdMmYyyy, parseDdMmYyyy, todayLocalISO } from '../date';

describe('parseDdMmYyyy', () => {
  it('parses a valid date', () => {
    expect(parseDdMmYyyy('05/07/2026')).toBe('2026-07-05');
    expect(parseDdMmYyyy('31/12/1999')).toBe('1999-12-31');
    expect(parseDdMmYyyy('01/01/2000')).toBe('2000-01-01');
  });

  it('handles leap years', () => {
    expect(parseDdMmYyyy('29/02/2024')).toBe('2024-02-29');
    expect(parseDdMmYyyy('29/02/2000')).toBe('2000-02-29'); // divisible by 400
    expect(parseDdMmYyyy('29/02/2026')).toBeNull();
    expect(parseDdMmYyyy('29/02/1900')).toBeNull(); // divisible by 100, not 400
  });

  it('rejects impossible calendar dates instead of rolling them forward', () => {
    expect(parseDdMmYyyy('31/02/2026')).toBeNull();
    expect(parseDdMmYyyy('31/04/2026')).toBeNull();
    expect(parseDdMmYyyy('32/01/2026')).toBeNull();
    expect(parseDdMmYyyy('00/01/2026')).toBeNull();
    expect(parseDdMmYyyy('01/00/2026')).toBeNull();
    expect(parseDdMmYyyy('01/13/2026')).toBeNull();
  });

  it('requires zero-padded DD/MM/YYYY exactly', () => {
    expect(parseDdMmYyyy('1/2/2026')).toBeNull();
    expect(parseDdMmYyyy('01/2/2026')).toBeNull();
    expect(parseDdMmYyyy('1/02/2026')).toBeNull();
    expect(parseDdMmYyyy('05/07/26')).toBeNull();
    expect(parseDdMmYyyy('2026-07-05')).toBeNull();
    expect(parseDdMmYyyy('05-07-2026')).toBeNull();
    expect(parseDdMmYyyy('05/07/2026extra')).toBeNull();
  });

  it('rejects garbage', () => {
    expect(parseDdMmYyyy('')).toBeNull();
    expect(parseDdMmYyyy(null)).toBeNull();
    expect(parseDdMmYyyy(undefined)).toBeNull();
    expect(parseDdMmYyyy('not a date')).toBeNull();
    expect(parseDdMmYyyy('//')).toBeNull();
    expect(parseDdMmYyyy('12345678')).toBeNull();
  });
});

describe('formatIsoToDdMmYyyy', () => {
  it('flips an ISO date to display order', () => {
    expect(formatIsoToDdMmYyyy('2026-07-05')).toBe('05/07/2026');
    expect(formatIsoToDdMmYyyy('2024-02-29')).toBe('29/02/2024');
  });

  it('does not shift the day across timezones', () => {
    // The 1st is the day that breaks under UTC parsing in a UTC- timezone, and
    // the last day of a month is the one that breaks in UTC+. Neither goes
    // through a Date here, so both are stable in any timezone the test runs in.
    expect(formatIsoToDdMmYyyy('2026-07-01')).toBe('01/07/2026');
    expect(formatIsoToDdMmYyyy('2026-07-31')).toBe('31/07/2026');
  });

  it('tolerates a trailing time part', () => {
    expect(formatIsoToDdMmYyyy('2026-07-05T00:00:00Z')).toBe('05/07/2026');
  });

  it('returns an empty string when there is nothing to show', () => {
    expect(formatIsoToDdMmYyyy(null)).toBe('');
    expect(formatIsoToDdMmYyyy(undefined)).toBe('');
    expect(formatIsoToDdMmYyyy('')).toBe('');
    expect(formatIsoToDdMmYyyy('nonsense')).toBe('');
  });

  it('round-trips with parseDdMmYyyy', () => {
    expect(parseDdMmYyyy(formatIsoToDdMmYyyy('2026-07-05'))).toBe('2026-07-05');
    expect(formatIsoToDdMmYyyy(parseDdMmYyyy('29/02/2024'))).toBe('29/02/2024');
  });
});

describe('todayLocalISO', () => {
  it('uses local calendar parts, not UTC', () => {
    // 00:30 IST on 25 July is 19:00 UTC on the 24th — toISOString() would say
    // the 24th. This is the bug that dated every after-midnight guest to
    // yesterday, so it's pinned with a faked clock rather than trusted.
    jest.useFakeTimers();
    try {
      const localMidnightish = new Date(2026, 6, 25, 0, 30, 0);
      jest.setSystemTime(localMidnightish);

      expect(todayLocalISO()).toBe('2026-07-25');
      expect(todayLocalISO()).toBe(
        `${localMidnightish.getFullYear()}-` +
          `${String(localMidnightish.getMonth() + 1).padStart(2, '0')}-` +
          `${String(localMidnightish.getDate()).padStart(2, '0')}`
      );
    } finally {
      jest.useRealTimers();
    }
  });

  it('zero-pads single-digit months and days', () => {
    jest.useFakeTimers();
    try {
      jest.setSystemTime(new Date(2026, 0, 3, 12, 0, 0));
      expect(todayLocalISO()).toBe('2026-01-03');
    } finally {
      jest.useRealTimers();
    }
  });

  it('produces something parseDdMmYyyy accepts once displayed', () => {
    expect(parseDdMmYyyy(formatIsoToDdMmYyyy(todayLocalISO()))).toBe(todayLocalISO());
  });
});

describe('firstOfThisMonthISO', () => {
  it('pins the day to 01 of the local current month', () => {
    jest.useFakeTimers();
    try {
      jest.setSystemTime(new Date(2026, 6, 25, 23, 45, 0));
      expect(firstOfThisMonthISO()).toBe('2026-07-01');

      jest.setSystemTime(new Date(2026, 0, 31, 0, 15, 0));
      expect(firstOfThisMonthISO()).toBe('2026-01-01');
    } finally {
      jest.useRealTimers();
    }
  });
});
