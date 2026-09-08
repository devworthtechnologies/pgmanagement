import { SANITY_FACTOR, checkAmountAgainstRent, describeAmountAnomaly } from '../paymentSanity';

describe('checkAmountAgainstRent', () => {
  it('passes amounts in proportion to the rent', () => {
    expect(checkAmountAgainstRent(5000, 5000)).toBeNull();
    expect(checkAmountAgainstRent(2500, 5000)).toBeNull(); // half — part payment
    expect(checkAmountAgainstRent(10000, 5000)).toBeNull(); // two months
    expect(checkAmountAgainstRent(15000, 5000)).toBeNull(); // exactly 3×, still fine
  });

  it('flags an amount more than 3x the rent', () => {
    expect(checkAmountAgainstRent(15001, 5000)).toEqual({ ratio: 15001 / 5000, direction: 'high' });
    expect(checkAmountAgainstRent(25000, 2500)).toEqual({ ratio: 10, direction: 'high' });
    // the classic fat-finger: one extra zero
    expect(checkAmountAgainstRent(50000, 5000).direction).toBe('high');
  });

  it('flags an amount below a third of the rent', () => {
    expect(checkAmountAgainstRent(5000 / 3, 5000)).toBeNull(); // exactly 1/3, fine
    expect(checkAmountAgainstRent(1600, 5000).direction).toBe('low');
    expect(checkAmountAgainstRent(50, 5000).direction).toBe('low');
    // dropped a zero
    expect(checkAmountAgainstRent(500, 5000).direction).toBe('low');
  });

  it('is symmetric around the configured factor', () => {
    const rent = 6000;
    expect(checkAmountAgainstRent(rent * SANITY_FACTOR, rent)).toBeNull();
    expect(checkAmountAgainstRent(rent * SANITY_FACTOR + 1, rent).direction).toBe('high');
    expect(checkAmountAgainstRent(rent / SANITY_FACTOR, rent)).toBeNull();
    expect(checkAmountAgainstRent(rent / SANITY_FACTOR - 1, rent).direction).toBe('low');
  });

  it('stays quiet when there is nothing to compare', () => {
    expect(checkAmountAgainstRent(5000, null)).toBeNull();
    expect(checkAmountAgainstRent(5000, 0)).toBeNull();
    expect(checkAmountAgainstRent(5000, undefined)).toBeNull();
    expect(checkAmountAgainstRent(5000, 'abc')).toBeNull();
    expect(checkAmountAgainstRent(null, 5000)).toBeNull();
    expect(checkAmountAgainstRent('', 5000)).toBeNull();
    expect(checkAmountAgainstRent(0, 5000)).toBeNull();
    expect(checkAmountAgainstRent(-100, 5000)).toBeNull();
    expect(checkAmountAgainstRent('abc', 5000)).toBeNull();
  });

  it('accepts numeric strings, since form fields hand it strings', () => {
    expect(checkAmountAgainstRent('50000', '5000').direction).toBe('high');
    expect(checkAmountAgainstRent('5000', '5000')).toBeNull();
  });
});

describe('describeAmountAnomaly', () => {
  it('builds the sentence from the prompt', () => {
    expect(describeAmountAnomaly(25000, 2500, 'Guest 2')).toBe(
      "₹25,000 is 10× Guest 2's monthly rent of ₹2,500. Record anyway?"
    );
  });

  it('describes an implausibly low amount as a fraction', () => {
    expect(describeAmountAnomaly(500, 5000, 'Rahul')).toBe(
      "₹500 is about 1/10 of Rahul's monthly rent of ₹5,000. Record anyway?"
    );
  });

  it('returns null when the amount is in proportion, so it doubles as the check', () => {
    expect(describeAmountAnomaly(5000, 5000, 'Rahul')).toBeNull();
    expect(describeAmountAnomaly(2500, 5000, 'Rahul')).toBeNull();
  });

  it('copes with a missing guest name', () => {
    expect(describeAmountAnomaly(50000, 5000, null)).toContain('monthly rent of ₹5,000');
    expect(describeAmountAnomaly(50000, 5000, null)).toContain('Record anyway?');
  });
});
