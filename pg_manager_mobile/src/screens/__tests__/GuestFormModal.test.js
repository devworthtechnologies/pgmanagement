import { buildGuestPayload } from '../GuestFormModal';

// lucide-react-native ships ESM-only .mjs, which jest-expo's transform doesn't
// pick up. Only the icon components need it and this suite never renders any —
// it tests one pure function out of the same module. babel-plugin-jest-hoist
// lifts this above the import, so the mock is in place before it resolves.
jest.mock('lucide-react-native', () => new Proxy({}, { get: () => 'Icon' }));

// The form's own state, as strings, exactly as the TextInputs hold it.
const formState = (overrides = {}) => ({
  roomId: 'room-uuid-1',
  fullName: 'Rahul Sharma',
  phone: '+91 98765 43210',
  monthlyRent: '8500',
  guestType: 'permanent',
  advancePaid: '5000',
  food: false,
  foodType: 'veg',
  stayDuration: '',
  stayUnit: 'months',
  aadharNumber: '',
  permanentAddress: '',
  joinedIso: '2026-07-05',
  ...overrides,
});

describe('buildGuestPayload — aadhaar key', () => {
  it('omits the key entirely when the field is blank', () => {
    // This is the whole bug. The edit form always starts blank (the server
    // never sends the number back), so an always-present key meant every
    // guest edit shipped aadhar_number: null and wiped the ID on file.
    const payload = buildGuestPayload(formState({ aadharNumber: '' }));
    expect('aadhar_number' in payload).toBe(false);
  });

  it('omits the key when the field holds only whitespace', () => {
    const payload = buildGuestPayload(formState({ aadharNumber: '   ' }));
    expect('aadhar_number' in payload).toBe(false);
  });

  it('never sends an explicit null', () => {
    for (const aadharNumber of ['', '  ', '\t']) {
      expect(buildGuestPayload(formState({ aadharNumber })).aadhar_number).toBeUndefined();
    }
  });

  it('includes the trimmed value when the user typed one', () => {
    const payload = buildGuestPayload(formState({ aadharNumber: '  1234 5678 9012  ' }));
    expect(payload.aadhar_number).toBe('1234 5678 9012');
  });
});

describe('buildGuestPayload — everything else', () => {
  it('maps the form onto the API field names', () => {
    const payload = buildGuestPayload(formState());
    expect(payload).toEqual({
      room_id: 'room-uuid-1',
      full_name: 'Rahul Sharma',
      phone: '+91 98765 43210',
      monthly_rent: 8500,
      guest_type: 'permanent',
      advance_paid: 5000,
      has_food: false,
      food_type: null,
      stay_duration: null,
      stay_unit: null,
      permanent_address: null,
      joined_at: '2026-07-05',
    });
  });

  it('trims the free-text fields', () => {
    const payload = buildGuestPayload(
      formState({ fullName: '  Priya  ', phone: ' 9876543210 ', permanentAddress: '  12 MG Road  ' })
    );
    expect(payload.full_name).toBe('Priya');
    expect(payload.phone).toBe('9876543210');
    expect(payload.permanent_address).toBe('12 MG Road');
  });

  it('nulls the optional numbers when their fields are empty', () => {
    const payload = buildGuestPayload(formState({ advancePaid: '', stayDuration: '' }));
    expect(payload.advance_paid).toBeNull();
    expect(payload.stay_duration).toBeNull();
    expect(payload.stay_unit).toBeNull();
  });

  it('sends the stay unit only alongside a duration', () => {
    const payload = buildGuestPayload(formState({ stayDuration: '6', stayUnit: 'months' }));
    expect(payload.stay_duration).toBe(6);
    expect(payload.stay_unit).toBe('months');
  });

  it('sends food_type only when food is required', () => {
    expect(buildGuestPayload(formState({ food: true, foodType: 'non_veg' })).food_type).toBe('non_veg');
    expect(buildGuestPayload(formState({ food: false, foodType: 'non_veg' })).food_type).toBeNull();
  });

  it('passes the join date through as the ISO string it was given', () => {
    // Already normalized by parseDdMmYyyy — no Date, no timezone shift here.
    expect(buildGuestPayload(formState({ joinedIso: '2026-03-01' })).joined_at).toBe('2026-03-01');
  });
});
