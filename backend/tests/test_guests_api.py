import pytest
import uuid
from datetime import datetime, timedelta, timezone
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User
from app.models.property import Property
from app.models.property_member import PropertyMember, PropertyRole
from app.models.room import Room, RoomType
from app.models.guest import Guest

@pytest.fixture
async def setup_guests_api(db_session: AsyncSession):
    from app.core.security import create_access_token
    
    owner = User(id=uuid.uuid4(), email="owner_guest_api@ex.com", password_hash="h", full_name="O", is_active=True)
    db_session.add(owner)
    await db_session.flush()  # owner must be INSERTed before rows FK-referencing it (no relationship() defined to auto-order)
    prop = Property(id=uuid.uuid4(), owner_id=owner.id, name="Prop G")
    db_session.add(prop)
    await db_session.flush()
    mem = PropertyMember(id=uuid.uuid4(), property_id=prop.id, user_id=owner.id, role=PropertyRole.OWNER)
    db_session.add(mem)
    
    room1 = Room(id=uuid.uuid4(), property_id=prop.id, room_number="101", room_type=RoomType.DOUBLE, capacity=2)
    room2 = Room(id=uuid.uuid4(), property_id=prop.id, room_number="102", room_type=RoomType.SINGLE, capacity=1)
    db_session.add(room1)
    db_session.add(room2)
    
    await db_session.commit()
    
    token = create_access_token(owner.id)
    
    return {
        "prop_id": prop.id,
        "room_1": room1.id,
        "room_2": room2.id,
        "token": token
    }

@pytest.mark.asyncio
async def test_guests_crud_and_aadhar_security(async_client: AsyncClient, setup_guests_api):
    prop_id = setup_guests_api["prop_id"]
    room_1 = setup_guests_api["room_1"]
    headers = {"Authorization": f"Bearer {setup_guests_api['token']}"}
    
    # 1. POST
    create_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/guests",
        json={
            "room_id": str(room_1),
            "full_name": "Test Guest",
            "phone": "9876543210",
            "monthly_rent": 5000,
            "joined_at": "2026-01-01",
            "aadhar_number": "123456789012"
        },
        headers=headers
    )
    assert create_resp.status_code == 201
    guest_data = create_resp.json()
    guest_id = guest_data["id"]
    
    # Explicitly verify the strict isolation of aadhar variables out of JSON schema
    assert guest_data["aadhar_last4"] == "9012"
    assert "aadhar_number_encrypted" not in guest_data
    assert "aadhar_number" not in guest_data
    
    # 2. GET (Single)
    get_resp = await async_client.get(f"/api/v1/properties/{prop_id}/guests/{guest_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["aadhar_last4"] == "9012"
    assert "aadhar_number_encrypted" not in get_resp.json()
    assert "aadhar_number" not in get_resp.json()
    
    # 3. PATCH
    patch_resp = await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_id}",
        json={"aadhar_number": "987654321098"},
        headers=headers
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["aadhar_last4"] == "1098"
    assert "aadhar_number_encrypted" not in patch_resp.json()
    assert "aadhar_number" not in patch_resp.json()

@pytest.mark.asyncio
async def test_guest_patch_without_aadhar_key_keeps_stored_value(
    async_client: AsyncClient, setup_guests_api, db_session: AsyncSession
):
    """
    Omitting aadhar_number must leave the stored ID alone; sending an explicit
    null must clear it. Two different intents that both used to look identical
    on the wire, because the edit form sent `aadhar_number: null` on every save
    (the field starts blank — the number is never sent back to the client) and
    so wiped the ID on file every time a guest was edited.
    """
    prop_id = setup_guests_api["prop_id"]
    room_1 = setup_guests_api["room_1"]
    headers = {"Authorization": f"Bearer {setup_guests_api['token']}"}

    create_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/guests",
        json={
            "room_id": str(room_1),
            "full_name": "Aadhar Keeper",
            "phone": "9876543210",
            "monthly_rent": 5000,
            "joined_at": "2026-01-01",
            "aadhar_number": "123456789012",
        },
        headers=headers
    )
    assert create_resp.status_code == 201
    guest_id = create_resp.json()["id"]
    assert create_resp.json()["aadhar_last4"] == "9012"

    # PATCH with NO aadhar_number key at all -> exclude_unset drops it, the
    # router's aadhar branch never runs, stored value survives.
    patch_resp = await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_id}",
        json={"full_name": "Aadhar Keeper Renamed"},
        headers=headers
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["full_name"] == "Aadhar Keeper Renamed"
    assert patch_resp.json()["aadhar_last4"] == "9012"

    # ...and the encrypted column behind it is still populated, not just last4.
    db_session.expire_all()
    row = (await db_session.execute(
        select(Guest.aadhar_number_encrypted, Guest.aadhar_last4).where(Guest.id == uuid.UUID(guest_id))
    )).one()
    assert row.aadhar_number_encrypted == b"123456789012"
    assert row.aadhar_last4 == "9012"

    # Explicit null still clears BOTH columns — that behaviour is correct and
    # deliberately kept reachable, there's just no UI asking for it today.
    clear_resp = await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_id}",
        json={"aadhar_number": None},
        headers=headers
    )
    assert clear_resp.status_code == 200
    assert clear_resp.json()["aadhar_last4"] is None

    db_session.expire_all()
    cleared = (await db_session.execute(
        select(Guest.aadhar_number_encrypted, Guest.aadhar_last4).where(Guest.id == uuid.UUID(guest_id))
    )).one()
    assert cleared.aadhar_number_encrypted is None
    assert cleared.aadhar_last4 is None

@pytest.mark.asyncio
async def test_guest_joined_at_manual_entry(async_client: AsyncClient, setup_guests_api):
    """
    Staff type the join date by hand, so it can be backdated (entering an
    existing tenant) but never postdated, and a typo is correctable via PATCH.
    Dates are computed from today so these stay meaningful next year.
    """
    prop_id = setup_guests_api["prop_id"]
    room_1 = setup_guests_api["room_1"]
    headers = {"Authorization": f"Bearer {setup_guests_api['token']}"}

    today = datetime.now(timezone.utc).date()
    backdated = today - timedelta(days=120)
    tomorrow = today + timedelta(days=1)

    # Backdated is fine — this is how existing tenants get entered.
    create_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/guests",
        json={
            "room_id": str(room_1),
            "full_name": "Backdated Guest",
            "phone": "9876543210",
            "monthly_rent": 5000,
            "joined_at": backdated.isoformat(),
        },
        headers=headers
    )
    assert create_resp.status_code == 201
    assert create_resp.json()["joined_at"] == backdated.isoformat()
    guest_id = create_resp.json()["id"]

    # Future is not.
    future_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/guests",
        json={
            "room_id": str(room_1),
            "full_name": "Future Guest",
            "phone": "9876543211",
            "monthly_rent": 5000,
            "joined_at": tomorrow.isoformat(),
        },
        headers=headers
    )
    assert future_resp.status_code == 400
    assert "future" in future_resp.json()["detail"].lower()

    # Neither is a year that's obviously a fat-fingered typo.
    ancient_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/guests",
        json={
            "room_id": str(room_1),
            "full_name": "Ancient Guest",
            "phone": "9876543212",
            "monthly_rent": 5000,
            "joined_at": "1999-12-31",
        },
        headers=headers
    )
    assert ancient_resp.status_code == 400
    assert "past" in ancient_resp.json()["detail"].lower()

    # A typo IS correctable now — GuestUpdateRequest accepts joined_at.
    corrected = today - timedelta(days=60)
    patch_resp = await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_id}",
        json={"joined_at": corrected.isoformat()},
        headers=headers
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["joined_at"] == corrected.isoformat()

    # ...but not to a future date.
    bad_patch = await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_id}",
        json={"joined_at": tomorrow.isoformat()},
        headers=headers
    )
    assert bad_patch.status_code == 400

@pytest.mark.asyncio
async def test_guest_joined_at_cannot_pass_move_out_date(async_client: AsyncClient, setup_guests_api):
    """
    A guest can't have joined after they moved out. The service checks the
    EFFECTIVE pair (stored value for whichever field the PATCH isn't touching)
    so this comes back as a readable 400, not a 500 from the DB constraint.
    """
    prop_id = setup_guests_api["prop_id"]
    room_1 = setup_guests_api["room_1"]
    headers = {"Authorization": f"Bearer {setup_guests_api['token']}"}

    today = datetime.now(timezone.utc).date()
    joined = today - timedelta(days=120)
    moved_out = today - timedelta(days=90)

    create_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/guests",
        json={
            "room_id": str(room_1),
            "full_name": "Moved Out Guest",
            "phone": "9876543213",
            "monthly_rent": 5000,
            "joined_at": joined.isoformat(),
        },
        headers=headers
    )
    assert create_resp.status_code == 201
    guest_id = create_resp.json()["id"]

    move_out_resp = await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_id}",
        json={"active": False, "moved_out_at": moved_out.isoformat()},
        headers=headers
    )
    assert move_out_resp.status_code == 200
    assert move_out_resp.json()["moved_out_at"] == moved_out.isoformat()

    # Push the join date past the stored move-out date -> 400
    bad_resp = await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_id}",
        json={"joined_at": (today - timedelta(days=30)).isoformat()},
        headers=headers
    )
    assert bad_resp.status_code == 400
    assert "move-out" in bad_resp.json()["detail"].lower()

    # Landing exactly ON the move-out date is allowed (joined and left same day).
    ok_resp = await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_id}",
        json={"joined_at": moved_out.isoformat()},
        headers=headers
    )
    assert ok_resp.status_code == 200
    assert ok_resp.json()["joined_at"] == moved_out.isoformat()

@pytest.mark.asyncio
async def test_guests_list_filtering(async_client: AsyncClient, setup_guests_api):
    prop_id = setup_guests_api["prop_id"]
    room_1 = setup_guests_api["room_1"]
    room_2 = setup_guests_api["room_2"]
    headers = {"Authorization": f"Bearer {setup_guests_api['token']}"}
    
    # Seed Guests
    await async_client.post(
        f"/api/v1/properties/{prop_id}/guests",
        json={"room_id": str(room_1), "full_name": "Alice", "phone": "1111111111", "monthly_rent": 5000, "joined_at": "2026-01-01"},
        headers=headers
    )
    guest_b_resp = await async_client.post(
        f"/api/v1/properties/{prop_id}/guests",
        json={"room_id": str(room_2), "full_name": "Bob", "phone": "2222222222", "monthly_rent": 6000, "joined_at": "2026-02-01"},
        headers=headers
    )
    guest_b_id = guest_b_resp.json()["id"]
    
    # Patch Bob inactive
    await async_client.patch(
        f"/api/v1/properties/{prop_id}/guests/{guest_b_id}",
        json={"active": False, "moved_out_at": "2026-03-01"},
        headers=headers
    )
    
    # 1. Filter: active=True
    resp1 = await async_client.get(f"/api/v1/properties/{prop_id}/guests?active=True", headers=headers)
    assert resp1.status_code == 200
    assert len(resp1.json()) == 1
    assert resp1.json()[0]["full_name"] == "Alice"
    
    # 2. Filter: room_id
    resp2 = await async_client.get(f"/api/v1/properties/{prop_id}/guests?room_id={room_2}", headers=headers)
    assert len(resp2.json()) == 1
    assert resp2.json()[0]["full_name"] == "Bob"
    
    # 3. Filter: search (name/phone combined lookup)
    resp3 = await async_client.get(f"/api/v1/properties/{prop_id}/guests?search=2222", headers=headers)
    assert len(resp3.json()) == 1
    assert resp3.json()[0]["full_name"] == "Bob"
