import pytest
import uuid
from datetime import date
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from app.models.user import User
from app.models.property import Property
from app.models.property_member import PropertyMember, PropertyRole
from app.models.room import Room, RoomType
from app.models.guest import Guest

@pytest.fixture
async def setup_payments_api(db_session: AsyncSession):
    from app.core.security import create_access_token
    
    owner = User(id=uuid.uuid4(), email="owner_payments_api@ex.com", password_hash="h", full_name="O", is_active=True)
    db_session.add(owner)
    await db_session.flush()  # owner must be INSERTed before rows FK-referencing it (no relationship() defined to auto-order)
    prop = Property(id=uuid.uuid4(), owner_id=owner.id, name="Prop P")
    db_session.add(prop)
    await db_session.flush()
    mem = PropertyMember(id=uuid.uuid4(), property_id=prop.id, user_id=owner.id, role=PropertyRole.OWNER)
    db_session.add(mem)
    
    room = Room(id=uuid.uuid4(), property_id=prop.id, room_number="101", room_type=RoomType.DOUBLE, capacity=2)
    db_session.add(room)
    await db_session.flush()  # same ordering issue: room must exist before guest FK-references it

    guest1 = Guest(
        id=uuid.uuid4(), property_id=prop.id, room_id=room.id,
        full_name="Guest 1", phone="1111111111", monthly_rent=5000, joined_at=date(2026, 1, 1)
    )
    guest2 = Guest(
        id=uuid.uuid4(), property_id=prop.id, room_id=room.id,
        full_name="Guest 2", phone="2222222222", monthly_rent=6000, joined_at=date(2026, 1, 1)
    )
    db_session.add(guest1)
    db_session.add(guest2)
    
    await db_session.commit()
    
    token = create_access_token(owner.id)
    
    return {
        "prop_id": prop.id,
        "guest_1": guest1.id,
        "guest_2": guest2.id,
        "token": token
    }

@pytest.mark.asyncio
async def test_payment_create_requires_idempotency_key(async_client: AsyncClient, setup_payments_api):
    prop_id = setup_payments_api["prop_id"]
    guest_1 = setup_payments_api["guest_1"]
    headers = {"Authorization": f"Bearer {setup_payments_api['token']}"}
    
    resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/payments",
        json={
            "guest_id": str(guest_1),
            "amount": 5000,
            "method": "upi",
            "for_month": "2026-07-01",
            # missing idempotency_key
        },
        headers=headers
    )
    assert resp.status_code == 422
    assert "idempotency_key" in str(resp.json())

@pytest.mark.asyncio
async def test_payments_list_filters(async_client: AsyncClient, setup_payments_api):
    prop_id = setup_payments_api["prop_id"]
    g1 = setup_payments_api["guest_1"]
    g2 = setup_payments_api["guest_2"]
    headers = {"Authorization": f"Bearer {setup_payments_api['token']}"}
    
    # 1. P1: G1, 2026-07
    await async_client.post(
        f"/api/v1/properties/{prop_id}/payments",
        json={"guest_id": str(g1), "amount": 5000, "method": "upi", "for_month": "2026-07-01", "idempotency_key": str(uuid.uuid4())},
        headers=headers
    )
    # 2. P2: G1, 2026-08
    await async_client.post(
        f"/api/v1/properties/{prop_id}/payments",
        json={"guest_id": str(g1), "amount": 5000, "method": "cash", "for_month": "2026-08-01", "idempotency_key": str(uuid.uuid4())},
        headers=headers
    )
    # 3. P3: G2, 2026-07
    await async_client.post(
        f"/api/v1/properties/{prop_id}/payments",
        json={"guest_id": str(g2), "amount": 6000, "method": "upi", "for_month": "2026-07-01", "idempotency_key": str(uuid.uuid4())},
        headers=headers
    )
    
    # Filter A: Test formatting parser correctly locks onto `month` logic 
    resp_month = await async_client.get(f"/api/v1/properties/{prop_id}/payments?month=2026-07", headers=headers)
    assert resp_month.status_code == 200
    assert len(resp_month.json()) == 2
    
    # Filter B: Test strict property guest-isolation 
    resp_guest = await async_client.get(f"/api/v1/properties/{prop_id}/payments?guest_id={g1}", headers=headers)
    assert resp_guest.status_code == 200
    assert len(resp_guest.json()) == 2

async def _record(client, prop_id, guest_id, headers, amount=5000, month="2026-07-01"):
    resp = await client.post(
        f"/api/v1/properties/{prop_id}/payments",
        json={"guest_id": str(guest_id), "amount": amount, "method": "upi",
              "for_month": month, "idempotency_key": str(uuid.uuid4())},
        headers=headers
    )
    assert resp.status_code == 201
    return resp.json()["id"]

@pytest.mark.asyncio
async def test_payment_void_marks_and_attributes_without_deleting(
    async_client: AsyncClient, setup_payments_api, db_session: AsyncSession
):
    """A void keeps the row in the ledger, marked and attributed. There is no
    DELETE route at all — the old one is gone on purpose."""
    prop_id = setup_payments_api["prop_id"]
    g1 = setup_payments_api["guest_1"]
    headers = {"Authorization": f"Bearer {setup_payments_api['token']}"}

    payment_id = await _record(async_client, prop_id, g1, headers)

    # The DELETE route is gone entirely. Asserted against the schema rather than
    # a status code, because a 404 here is ambiguous — it would also be what a
    # missing payment returns.
    spec = (await async_client.get("/openapi.json")).json()
    payment_item_path = "/api/v1/properties/{property_id}/payments/{payment_id}"
    assert "delete" not in spec["paths"].get(payment_item_path, {})
    assert "post" in spec["paths"][payment_item_path + "/void"]
    assert "post" in spec["paths"][payment_item_path + "/correct"]

    void_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/payments/{payment_id}/void",
        json={"reason": "guest paid cash, recorded twice"},
        headers=headers
    )
    assert void_resp.status_code == 200
    assert void_resp.json()["deleted_at"] is not None
    assert void_resp.json()["void_reason"] == "guest paid cash, recorded twice"
    assert void_resp.json()["voided_by"] is not None

    # Default listing hides it; include_voided surfaces it for history.
    default_list = await async_client.get(f"/api/v1/properties/{prop_id}/payments", headers=headers)
    assert len(default_list.json()) == 0

    with_voided = await async_client.get(
        f"/api/v1/properties/{prop_id}/payments?include_voided=true", headers=headers
    )
    assert len(with_voided.json()) == 1
    assert with_voided.json()[0]["id"] == payment_id

    # The row genuinely still exists in the table.
    result = await db_session.execute(text(f"SELECT deleted_at, void_reason FROM payments WHERE id = '{payment_id}'"))
    row = result.fetchone()
    assert row is not None and row[0] is not None and row[1] is not None

@pytest.mark.asyncio
async def test_payment_void_requires_manager(async_client: AsyncClient, setup_payments_api, db_session: AsyncSession):
    """Staff can RECORD a payment but not undo it. Whoever takes the cash must
    not also be able to erase the record of having taken it."""
    from app.core.security import create_access_token

    prop_id = setup_payments_api["prop_id"]
    g1 = setup_payments_api["guest_1"]
    owner_headers = {"Authorization": f"Bearer {setup_payments_api['token']}"}

    staff = User(id=uuid.uuid4(), email="staff_void@ex.com", password_hash="h", full_name="S", is_active=True)
    db_session.add(staff)
    await db_session.flush()
    db_session.add(PropertyMember(
        id=uuid.uuid4(), property_id=prop_id, user_id=staff.id, role=PropertyRole.STAFF
    ))
    await db_session.commit()
    staff_headers = {"Authorization": f"Bearer {create_access_token(staff.id)}"}

    # Staff CAN record.
    payment_id = await _record(async_client, prop_id, g1, staff_headers)

    # ...but cannot void.
    denied = await async_client.post(
        f"/api/v1/properties/{prop_id}/payments/{payment_id}/void",
        json={"reason": "oops"}, headers=staff_headers
    )
    assert denied.status_code == 403

    # ...nor correct.
    denied_correct = await async_client.post(
        f"/api/v1/properties/{prop_id}/payments/{payment_id}/correct",
        json={"guest_id": str(g1), "amount": 100, "method": "upi",
              "for_month": "2026-07-01", "idempotency_key": str(uuid.uuid4())},
        headers=staff_headers
    )
    assert denied_correct.status_code == 403

    # Still live, untouched by the refused attempts.
    still_there = await async_client.get(f"/api/v1/properties/{prop_id}/payments", headers=owner_headers)
    assert [p["id"] for p in still_there.json()] == [payment_id]

@pytest.mark.asyncio
async def test_payment_correct_voids_old_and_links_new(async_client: AsyncClient, setup_payments_api):
    prop_id = setup_payments_api["prop_id"]
    g1 = setup_payments_api["guest_1"]
    headers = {"Authorization": f"Bearer {setup_payments_api['token']}"}

    wrong_id = await _record(async_client, prop_id, g1, headers, amount=50000)

    corrected = await async_client.post(
        f"/api/v1/properties/{prop_id}/payments/{wrong_id}/correct",
        json={"guest_id": str(g1), "amount": 5000, "method": "cash",
              "for_month": "2026-07-01", "idempotency_key": str(uuid.uuid4()),
              "reason": "typo: 50000 should have been 5000"},
        headers=headers
    )
    assert corrected.status_code == 201
    new_payment = corrected.json()
    assert float(new_payment["amount"]) == 5000.0
    assert new_payment["corrects_payment_id"] == wrong_id
    assert new_payment["deleted_at"] is None

    # Only the replacement is live.
    live = await async_client.get(f"/api/v1/properties/{prop_id}/payments", headers=headers)
    assert [p["id"] for p in live.json()] == [new_payment["id"]]

    # Both rows visible in history, the original carrying the reason.
    history = await async_client.get(
        f"/api/v1/properties/{prop_id}/payments?include_voided=true", headers=headers
    )
    by_id = {p["id"]: p for p in history.json()}
    assert len(by_id) == 2
    assert by_id[wrong_id]["deleted_at"] is not None
    assert by_id[wrong_id]["void_reason"] == "typo: 50000 should have been 5000"

@pytest.mark.asyncio
async def test_payment_correct_is_atomic(async_client: AsyncClient, setup_payments_api):
    """
    If the create half fails, the void half must not stick. Forced here with a
    guest_id that doesn't belong to the property — the service voids first, then
    raises on the guest check, so this genuinely exercises the rollback rather
    than a pre-flight validation.
    """
    prop_id = setup_payments_api["prop_id"]
    g1 = setup_payments_api["guest_1"]
    headers = {"Authorization": f"Bearer {setup_payments_api['token']}"}

    payment_id = await _record(async_client, prop_id, g1, headers)

    broken = await async_client.post(
        f"/api/v1/properties/{prop_id}/payments/{payment_id}/correct",
        json={"guest_id": str(uuid.uuid4()), "amount": 5000, "method": "upi",
              "for_month": "2026-07-01", "idempotency_key": str(uuid.uuid4())},
        headers=headers
    )
    assert broken.status_code == 400

    # The original is NOT voided and no replacement was written.
    live = await async_client.get(f"/api/v1/properties/{prop_id}/payments", headers=headers)
    assert [p["id"] for p in live.json()] == [payment_id]
    assert live.json()[0]["deleted_at"] is None

    history = await async_client.get(
        f"/api/v1/properties/{prop_id}/payments?include_voided=true", headers=headers
    )
    assert len(history.json()) == 1

@pytest.mark.asyncio
async def test_voided_payment_stops_counting_as_money(async_client: AsyncClient, setup_payments_api):
    """
    THE money test. A voided payment must not count toward collected totals or
    reduce a guest's outstanding balance — otherwise voiding is cosmetic and the
    books stay wrong. Asserts the dashboard returns to its exact pre-payment
    numbers, not merely that they changed.
    """
    prop_id = setup_payments_api["prop_id"]
    g1 = setup_payments_api["guest_1"]  # monthly_rent 5000
    headers = {"Authorization": f"Bearer {setup_payments_api['token']}"}

    async def dashboard():
        r = await async_client.get(
            f"/api/v1/properties/{prop_id}/stats/dashboard?month=2026-07", headers=headers
        )
        assert r.status_code == 200
        d = r.json()
        due = {e["guest_id"]: float(e["balance"]) for e in d["due_guests"]}
        return float(d["collected_this_month"]), float(d["total_collected"]), float(d["pending_rent"]), due

    before = await dashboard()
    collected_before, total_before, pending_before, due_before = before
    assert due_before[str(g1)] == 5000.0  # full rent outstanding

    payment_id = await _record(async_client, prop_id, g1, headers, amount=5000)

    collected_after, total_after, pending_after, due_after = await dashboard()
    assert collected_after == collected_before + 5000.0
    assert total_after == total_before + 5000.0
    assert pending_after == pending_before - 5000.0
    assert str(g1) not in due_after  # settled for the month

    void_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/payments/{payment_id}/void",
        json={"reason": "recorded against the wrong guest"}, headers=headers
    )
    assert void_resp.status_code == 200

    # Every figure back exactly where it started.
    assert await dashboard() == before
