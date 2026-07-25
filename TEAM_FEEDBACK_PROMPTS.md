# Claude Code prompts — team feedback round 1

Two features: room default rent, manual guest joining date.
Run **Prompt 1 first**, let it finish and pass tests, then Prompt 2 (they touch the same alembic chain and the same two form screens).

---

## Read this before you paste

Three calls I made on your behalf, plus one bug you didn't ask about.

**1. Room rent divides by `capacity`, not by how many people currently live there.**
You said "2 sharing room 10k, 5k each." Fine — but there are two ways to read "each": divide by beds, or divide by *occupants*. Divide by occupants and you get this: guest A moves into an empty 2-sharing room and is prefilled ₹10,000. Guest B joins next week and is prefilled ₹5,000. Now two people in the same room pay different rent for no reason, and A is furious. Divide by capacity and the number is stable forever. It's a prefill — staff can override it for a solo occupant who genuinely pays double.

**2. The room's rent is a template, not a live link.**
`guests.monthly_rent` stays the source of truth for billing. The room field only prefills the guest form at creation time. If it were a reference, then editing a room's rent in December would silently rewrite every payment balance back to day one — including guests who moved out. Both prompts state this as a hard constraint and Prompt 1 adds a test that locks it down.

**3. ₹10,000 ÷ 3 beds = ₹3,333.33.** It rounds to whole rupees, so 3 guests × ₹3,334 = ₹10,002. Nobody cares, it's a prefill, staff overrides it. Just don't be surprised.

**And the thing your team will complain about next:** backdating a guest to March does **not** produce unpaid rent for April, May, June. Your dashboard only ever bills the currently-selected month — `balance_for_month()` in `rent_reconciliation.py` doesn't even look at the join date. So someone will enter three months of old data, expect to see ₹27,000 outstanding, and see ₹0. That's arrears tracking and it's a real project — separate release, don't let it get bolted onto this one.

**Free bug fix included in Prompt 2:** `GuestFormModal.js:133` uses `new Date().toISOString()`, which is UTC. Between midnight and 5:30am IST, every guest you add is currently dated *yesterday*.

---

## PROMPT 1 — Default rent on rooms

```
Add a default rent field to rooms in this repo (FastAPI backend + Expo/React Native
frontend, both in this workspace).

GOAL
When creating a room, staff can set the room's monthly rent for the WHOLE room.
When they later add a guest to that room, the guest's monthly rent field is
pre-filled with the per-guest share. Room rent stays editable afterwards.

THE ARITHMETIC — do exactly this
  per_guest_rent = round(room.default_rent / room.capacity)
Divide by CAPACITY. Never by occupied_beds. A ₹10,000 2-sharing room prefills
₹5,000 per guest whether one person or two people live there.
Round half-up to whole rupees.

HARD CONSTRAINTS — violating any of these is a failed task
- guests.monthly_rent remains the sole source of truth for all billing.
  rooms.default_rent is a prefill template ONLY.
- Editing a room's default_rent or capacity must NOT change any existing
  guest's monthly_rent. No cascade, no trigger, no backfill, no "update all
  guests in this room" convenience feature.
- Do not modify app/services/rent_reconciliation.py, app/services/stats_service.py,
  or app/services/payment_service.py. At all.
- default_rent is NULLABLE. Existing rooms have none and must keep working.

BACKEND (backend/)
1. app/models/room.py — add:
     default_rent: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
   plus CheckConstraint('default_rent IS NULL OR default_rent >= 0',
   name='chk_rooms__default_rent') in __table_args__.
2. New alembic migration in alembic/versions/. Run `alembic heads` first and set
   down_revision to the actual current head (it should be h8i9j0k1l2m3). Match the
   file naming and op.f() style of the existing migrations. upgrade() adds the
   column + constraint; downgrade() drops both.
3. app/schemas/room.py — add `default_rent: float | None = Field(None, ge=0)` to
   RoomCreateRequest, RoomUpdateRequest and RoomResponse.
4. app/services/room_service.py — read it first, then thread default_rent through
   create_room() and update_room() the same way advance_details is handled.
5. app/api/v1/routers/rooms.py — serialize_room() dumps all table columns, so it
   should pick this up for free. Verify that, don't assume it.

FRONTEND (pg_manager_mobile/)
6. src/lib/rent.js — add and export:
     perGuestRent(defaultRent, capacity)
   Returns null if defaultRent is null/undefined/NaN or capacity < 1.
   Otherwise Math.round(Number(defaultRent) / Number(capacity)).
7. src/screens/RoomFormModal.js — add a FormField above the existing
   "Advance / deposit" field:
     label: "Room rent (₹/month — full room)"
     testID: "room-default-rent-input", keyboardType numeric
     placeholder "e.g. 10000"
   Validate like advanceDetails does (optional, but if filled must be a finite
   number >= 0). Under the field show live helper text when both rent and
   capacity are filled, e.g. "₹10,000 ÷ 2 beds = ₹5,000 per guest", using
   perGuestRent(). Wire it into the create and update payloads as default_rent.
8. src/screens/GuestFormModal.js — prefill logic:
   - Add a `rentTouched` state flag, set to true inside the monthly rent
     onChangeText handler.
   - When a room chip is selected AND we are creating (editingGuest is null)
     AND rentTouched is false: setMonthlyRent(String(perGuestRent(room.default_rent,
     room.capacity))).
   - If perGuestRent returns null, leave the rent field exactly as it is.
     Do not clear it.
   - NEVER prefill when editing an existing guest.
9. src/screens/RoomsScreen.js — read it, then show the per-guest rent on each room
   card when default_rent is set. Match the card's existing visual style; don't
   redesign anything.

TESTS
- backend/tests/test_rooms_api.py and test_room_service.py: create room with
  default_rent, PATCH it, create without it (null), reject negative (422).
- Add a test proving the constraint above: create a room with default_rent, add a
  guest to it, PATCH the room's default_rent to a different value, then assert the
  guest's monthly_rent is unchanged.
- pg_manager_mobile/src/lib/__tests__/rent.test.js: perGuestRent cases including
  10000/3 → 3333, null default, capacity 0, capacity 1.
- Run `pytest` in backend/ and `npm test` in pg_manager_mobile/. Report pass/fail
  counts for both. Do not tell me it's done until both suites are green.
```

---

## PROMPT 2 — Manual guest joining date

```
Let staff set a guest's joining date manually instead of it being hardcoded to
today. FastAPI backend + Expo/React Native frontend, both in this workspace.

CONTEXT — most of the backend already exists
guests.joined_at is already a required Date column and GuestCreateRequest already
accepts it. The bugs are:
  a) GuestFormModal.js line ~133 hardcodes `new Date().toISOString().slice(0,10)`
  b) that expression is UTC — in IST it returns YESTERDAY between 00:00 and 05:30
  c) GuestUpdateRequest has no joined_at, so a typo can never be corrected

HARD CONSTRAINTS
- Do NOT touch app/services/rent_reconciliation.py or app/services/stats_service.py.
  Backdating a guest must not create arrears for past months. Out of scope,
  separate release.
- Do NOT add a date-picker dependency. This app ships to web via react-native-web
  on Cloudflare Pages; @react-native-community/datetimepicker does not work there.
  Typed input only.

BACKEND (backend/)
1. app/schemas/guest.py — add `joined_at: date | None = None` to GuestUpdateRequest.
2. app/services/guest_service.py — validate in BOTH add_guest() and update_guest():
   - joined_at must not be after today (use datetime.now(timezone.utc).date()) →
     raise ValueError("joined_at: Join date cannot be in the future.")
   - joined_at must not be before 2000-01-01 →
     raise ValueError("joined_at: Join date is too far in the past.")
   - the effective moved_out_at must be >= the effective joined_at. On update,
     compare against the stored value for whichever field isn't being changed →
     raise ValueError("joined_at: Join date must be on or before the move-out date.")
   Verify the update route in app/api/v1/routers/guests.py maps ValueError to a 400
   the same way the create route does. Fix it if it doesn't.
3. New alembic migration: add
   CheckConstraint('moved_out_at IS NULL OR moved_out_at >= joined_at',
   name='chk_guests__moved_out_after_joined') to the guests table, and add the
   matching CheckConstraint to app/models/guest.py __table_args__.
   Run `alembic heads` and chain down_revision off the actual current head.
   If existing rows violate it the migration should fail loudly — do not add a
   data-cleanup step to paper over it, just tell me.

FRONTEND (pg_manager_mobile/)
4. New file src/lib/date.js, exporting:
   - todayLocalISO() → 'YYYY-MM-DD' built from getFullYear/getMonth/getDate.
     Local time. Never toISOString().
   - parseDdMmYyyy(str) → 'YYYY-MM-DD' or null. Strict: must be exactly
     DD/MM/YYYY and a real calendar date. '31/02/2026' → null.
     '29/02/2024' → '2024-02-29'. '29/02/2026' → null.
   - formatIsoToDdMmYyyy(iso) → 'DD/MM/YYYY' or ''. Must not go through
     new Date() — string-split it, so no timezone can shift the day.
   - firstOfThisMonthISO()
5. src/screens/GuestFormModal.js:
   - `joinDate` state, holding the DD/MM/YYYY display string.
     Default on create: formatIsoToDdMmYyyy(todayLocalISO()).
     On edit: formatIsoToDdMmYyyy(editingGuest.joined_at).
   - FormField: label "Joining date", placeholder "DD/MM/YYYY",
     keyboardType numeric, testID "guest-joined-input". Auto-insert the "/"
     separators as the user types digits, and let backspace delete through them.
   - Two Chips below it, styled like the existing chip rows: "Today" and
     "1st of this month".
   - Validate on save: required, must parse via parseDdMmYyyy, not in the future,
     not before 2000. Show the error through the existing `errors` mechanism.
   - Create payload: joined_at: parseDdMmYyyy(joinDate). DELETE the
     `new Date().toISOString().slice(0, 10)` line.
   - Update payload: include joined_at. Delete the now-wrong comment above it that
     says the join date can't be changed after creation.
6. src/screens/GuestDetailScreen.js line ~166 — it currently does
   format(new Date(guest.joined_at), ...), which parses as UTC midnight.
   Swap it to formatIsoToDdMmYyyy().

TESTS
- pg_manager_mobile/src/lib/__tests__/date.test.js — parseDdMmYyyy across leap
  years, 31/02, 00/01/2026, '1/2/2026' (reject, not zero-padded), garbage strings;
  formatIsoToDdMmYyyy round-trip; todayLocalISO uses local date parts.
- backend/tests/test_guests_api.py — create with a backdated joined_at (200),
  create with a future joined_at (400), PATCH joined_at (200), PATCH joined_at to
  after an existing moved_out_at (400).
- Run `pytest` in backend/ and `npm test` in pg_manager_mobile/. Both green before
  you report done.
```

---

## After both land

- `alembic upgrade head` locally, then on Railway. Two new migrations, run in order.
- Add a guest at 1am IST and confirm the join date is today, not yesterday.
- Create a 3-sharing room at ₹10,000, add a guest → rent should prefill ₹3,333.
- Set a room's rent, add a guest, change the room's rent, reopen the guest →
  their rent must be untouched. This is the one that matters.
