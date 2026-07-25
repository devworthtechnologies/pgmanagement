# Handoff — pgmanagement

Last session: 25 Jul 2026. Written for a fresh Claude Code session with no prior context.

---

## Do this first

**25 files are uncommitted.** The payment void/correction feature, the docker-compose project-name fix, and the flaky-test fix are all sitting loose in the working tree. Commit before touching anything.

```
git add -A
git commit -m "feat: payment void + correction, compose project isolation, fix flaky jwt test"
```

Last commit is `ba6151a`, which covers the batch before this one.

---

## What the project is

PG (paying-guest hostel) management app for Indian PG owners.

- `backend/` — FastAPI + Postgres + Redis, SQLAlchemy async, alembic. Deploys to Railway.
- `pg_manager_mobile/` — Expo / React Native, also builds to web via react-native-web. Deploys to Cloudflare Pages.

Web is the primary channel today. Native app stores are not submitted to and are not a near-term goal.

---

## Shipped in the last session (4 batches)

**1. Room default rent.** `rooms.default_rent` is the **whole-room** monthly rent. The guest form prefills each guest's rent as `round(default_rent / capacity)`. `RoomsScreen` cards show both figures.

**2. Manual guest joining date.** `joined_at` is now a typed `DD/MM/YYYY` field with Today / 1st-of-month chips, editable after creation. Backend validates future dates, pre-2000 dates, and move-out ordering. Fixed a UTC bug that dated guests a day early between 00:00–05:30 IST.

**3. Multi-PG unlock.** Owners can hold several PGs under one login. `PropertyPickerModal` switches between them and adds new ones. This capability already existed in the schema (`properties` + `property_members`); only the UI was missing.

**4. Payment void + correction.** Payments are an append-only ledger. A wrong entry is voided and re-entered atomically via `POST /payments/{id}/correct`; the new row links back through `corrects_payment_id`. Voided rows stay visible, struck through, and never count toward any total. `POST /payments/{id}/void` and `/correct` both require manager or above. A fat-finger guard warns when an amount is >3× or <⅓ of the guest's monthly rent.

Also fixed along the way: guest edits silently wiping the stored Aadhaar; Settings renaming the wrong PG after a switch; new signups landing on a dead spinner; stale data from the previous PG rendering after a switch; a JWT test with a 6.15% false-pass rate; and `pytest` destroying the dev database.

Suites at handoff: **backend 85 passed, mobile 63 passed.**

---

## Deploying — read before you push

**Backend must deploy before frontend.** `api.js` no longer has `payments.remove()`; it calls `/void` and `/correct`. A new frontend against an old backend 404s on both. The reverse order is safe — an old frontend against a new backend just loses the delete button.

**Three migrations are unreleased.** Run in order:

```
i9j0k1l2m3n4_add_rooms_default_rent
j0k1l2m3n4o5_add_guests_moved_out_after_joined_check
k1l2m3n4o5p6_add_payment_void_and_correction
```

`alembic upgrade head` locally, then on Railway, then push the web build.

---

## Invariants — do not break these

Every one of these was a deliberate decision. If a change seems to require breaking one, stop and ask.

1. **`rooms.default_rent` is a prefill template, never a live reference.** Changing a room's rent or capacity must never alter an existing guest's `monthly_rent`. Locked by `test_room_default_rent_never_cascades_to_guest_rent`.
2. **Divide room rent by `capacity`, never by `occupied_beds`.** Occupant-based division gives two people in the same room different rent.
3. **`guests.monthly_rent` is the sole source of truth for billing.**
4. **The payments ledger is append-only.** Void and re-enter. Never add a plain edit endpoint — it destroys the audit trail that settles guest disputes and exposes staff skimming.
5. **`useStore` sets `user` and `properties` in a single `set()` call.** `App.js` keys the navigator on `user` and reads `initialRouteName` at that instant. Split them across two calls and new signups break again.
6. **`initialRouteName` in `App.js` is not reactive.** It is only read when the navigator key flips. Comment in the file says so.
7. **Backdating a guest must not generate arrears.** `balance_for_month` bills only the selected month, on purpose.

---

## Open decisions — need kaipulla's call

1. **Voider names.** The ledger shows "Voided by you" / "by a manager", not a name. Resolving names needs `full_name` added to the members endpoint, which was deliberately not exposed.
2. **Idempotency key on voided payments.** `get_by_idempotency_key` filters out voided rows, but `uq_payments__property_id_idempotency_key` has no partial index — so reusing a voided key passes the service check and then fails at the DB. Not reachable through the UI. Fix is either a partial unique index or dropping the filter.
3. **Dashboard padding.** `paddingHorizontal` is applied at two DOM levels, costing 48px of content width across the whole Dashboard. Real, pre-existing, and fixing it widens every card — look at before/after screenshots first.

---

## Debt list

- **`usePropertyScopedData` hook.** Four screens carry identical fetch-and-guard logic. That duplication is why one bug landed in four places. This is the right refactor; it was deferred because there's no safety net for it.
- **No component-test infrastructure.** Only pure functions and the store are tested. No screen has coverage.
- **~201 eslint errors**, all pre-existing: jest globals undeclared for `__tests__`, plus set-state-in-effect in the three form-hydration modals. The next real error is invisible until this is cleaned up.
- **Staff-cannot-void UI path never clicked through.** The security boundary is covered by `test_payment_void_requires_manager`; only the button-hiding is unverified.

---

## Explicitly out of scope — do not build

- **Payments / subscriptions / Razorpay.** Billing lives on the landing page, outside the app. Nothing about plans, prices, or checkout goes in the app — that is both a deliberate product call and an App Store policy requirement.
- **Arrears.** Backdating a guest to March does not create unpaid rent for April–June. Rewriting `rent_reconciliation` for this is its own release.
- **Guest-facing interface.** Later, and only after owners are paying.
- **Separate account per PG, non-unique emails, or login by PG name.** Evaluated and rejected. It breaks password reset, destroys the audit trail, breaks managers working across branches, and buys zero extra ability to collect money — billing is gated by a per-property subscription row, not by the login.

---

## Local dev notes

- Compose projects are now isolated: `pgmanager_dev` (:5432, :6379) and `pgmanager_test` (:5433, :6380). `pytest` can no longer destroy dev data. It does still recreate the **test** DB each session, so re-seed if the app is pointed there.
- Don't run `pytest` while manually clicking through the app.
- `docker volume rm docker_postgres_data` — old pre-rename dev volume, kept as a fallback. Delete once you're satisfied the migration took. There's also a stray `backend_postgres-data` from an earlier run.
- Throwaway local accounts (local docker only, recreated by pytest): `verify.multipg@localtest.dev` / `localtest-throwaway-1`, and `freshsignup@localtest.dev` / `localtest-throwaway-2` for the zero-PG onboarding path.

---

## A note on how this project has been working

Green test suites have twice passed while the app was broken for every new user. Tests confirm the code does what the code says; they cannot confirm that React Navigation re-reads a prop or that a race resolves in the right order.

Every substantial change here has been verified at runtime — driving the browser, injecting fetch delays to make races observable, checking the encrypted column in the database rather than trusting the displayed last-4. Hold to that standard. Report what you saw on screen, not what the code should do.
