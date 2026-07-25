import pytest
import uuid
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User
from app.models.property import Property
from app.models.property_member import PropertyMember, PropertyRole

@pytest.fixture
async def setup_multitenant_rooms(db_session: AsyncSession):
    from app.core.security import create_access_token
    
    # 1. Setup Property A and its staff member
    user_a = User(id=uuid.uuid4(), email="staff_a_room@ex.com", password_hash="h", full_name="A", is_active=True)
    db_session.add(user_a)
    await db_session.flush()  # user_a must be INSERTed before prop_a FK-references it
    prop_a = Property(id=uuid.uuid4(), owner_id=user_a.id, name="Prop A Room")
    db_session.add(prop_a)
    await db_session.flush()
    mem_a = PropertyMember(id=uuid.uuid4(), property_id=prop_a.id, user_id=user_a.id, role=PropertyRole.STAFF)
    db_session.add(mem_a)
    
    # 2. Setup Property B and its staff member
    user_b = User(id=uuid.uuid4(), email="staff_b_room@ex.com", password_hash="h", full_name="B", is_active=True)
    db_session.add(user_b)
    await db_session.flush()  # user_b must be INSERTed before prop_b FK-references it
    prop_b = Property(id=uuid.uuid4(), owner_id=user_b.id, name="Prop B Room")
    db_session.add(prop_b)
    await db_session.flush()
    mem_b = PropertyMember(id=uuid.uuid4(), property_id=prop_b.id, user_id=user_b.id, role=PropertyRole.STAFF)
    db_session.add(mem_b)
    
    await db_session.commit()
    
    token_a = create_access_token(user_a.id)
    token_b = create_access_token(user_b.id)
    
    return {
        "prop_a": prop_a.id,
        "token_a": token_a,
        "prop_b": prop_b.id,
        "token_b": token_b
    }

@pytest.mark.asyncio
async def test_rooms_crud(async_client: AsyncClient, setup_multitenant_rooms):
    prop_a = setup_multitenant_rooms["prop_a"]
    token_a = setup_multitenant_rooms["token_a"]
    headers = {"Authorization": f"Bearer {token_a}"}
    
    # 1. POST
    create_resp = await async_client.post(
        f"/api/v1/properties/{prop_a}/rooms",
        json={"room_number": "101", "room_type": "single", "capacity": 1},
        headers=headers
    )
    assert create_resp.status_code == 201
    room_data = create_resp.json()
    room_id = room_data["id"]
    
    assert room_data["occupied_beds"] == 0
    assert room_data["status"] == "Available"
    
    # Duplicate POST -> 409
    dup_resp = await async_client.post(
        f"/api/v1/properties/{prop_a}/rooms",
        json={"room_number": "101", "room_type": "double", "capacity": 2},
        headers=headers
    )
    assert dup_resp.status_code == 409

    # 2. GET (List)
    list_resp = await async_client.get(f"/api/v1/properties/{prop_a}/rooms", headers=headers)
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1
    
    # 3. GET (Single)
    get_resp = await async_client.get(f"/api/v1/properties/{prop_a}/rooms/{room_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["room_number"] == "101"
    
    # 4. PATCH
    patch_resp = await async_client.patch(
        f"/api/v1/properties/{prop_a}/rooms/{room_id}",
        json={"capacity": 2},
        headers=headers
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["capacity"] == 2
    
    # 5. DELETE -> the guests table now exists (built in Phase 3), so the room
    # has zero occupants and the delete succeeds cleanly with 204.
    delete_resp = await async_client.delete(f"/api/v1/properties/{prop_a}/rooms/{room_id}", headers=headers)
    assert delete_resp.status_code == 204

@pytest.mark.asyncio
async def test_room_default_rent_roundtrip(async_client: AsyncClient, setup_multitenant_rooms):
    prop_a = setup_multitenant_rooms["prop_a"]
    headers = {"Authorization": f"Bearer {setup_multitenant_rooms['token_a']}"}

    # Create with a default_rent
    resp = await async_client.post(
        f"/api/v1/properties/{prop_a}/rooms",
        json={"room_number": "201", "room_type": "double", "capacity": 2, "default_rent": 10000},
        headers=headers
    )
    assert resp.status_code == 201
    assert float(resp.json()["default_rent"]) == 10000.0
    room_id = resp.json()["id"]

    # PATCH it
    patch_resp = await async_client.patch(
        f"/api/v1/properties/{prop_a}/rooms/{room_id}",
        json={"default_rent": 12500},
        headers=headers
    )
    assert patch_resp.status_code == 200
    assert float(patch_resp.json()["default_rent"]) == 12500.0

    # It survives the list/detail serializer too
    get_resp = await async_client.get(f"/api/v1/properties/{prop_a}/rooms/{room_id}", headers=headers)
    assert float(get_resp.json()["default_rent"]) == 12500.0

    # Create without one — pre-existing rooms have no default rent and must
    # keep working.
    null_resp = await async_client.post(
        f"/api/v1/properties/{prop_a}/rooms",
        json={"room_number": "202", "room_type": "single", "capacity": 1},
        headers=headers
    )
    assert null_resp.status_code == 201
    assert null_resp.json()["default_rent"] is None

    # Negative rejected by the schema before it ever reaches the DB constraint
    neg_resp = await async_client.post(
        f"/api/v1/properties/{prop_a}/rooms",
        json={"room_number": "203", "room_type": "single", "capacity": 1, "default_rent": -1},
        headers=headers
    )
    assert neg_resp.status_code == 422

    neg_patch = await async_client.patch(
        f"/api/v1/properties/{prop_a}/rooms/{room_id}",
        json={"default_rent": -500},
        headers=headers
    )
    assert neg_patch.status_code == 422

@pytest.mark.asyncio
async def test_room_default_rent_never_cascades_to_guest_rent(async_client: AsyncClient, setup_multitenant_rooms):
    """
    rooms.default_rent is a prefill template. guests.monthly_rent is the sole
    source of truth for billing. Editing a room's rent must NOT rewrite the
    rent of anyone already living in it — otherwise changing a room's rate in
    December silently re-bills every month back to move-in day.
    """
    prop_a = setup_multitenant_rooms["prop_a"]
    headers = {"Authorization": f"Bearer {setup_multitenant_rooms['token_a']}"}

    room_resp = await async_client.post(
        f"/api/v1/properties/{prop_a}/rooms",
        json={"room_number": "301", "room_type": "double", "capacity": 2, "default_rent": 10000},
        headers=headers
    )
    assert room_resp.status_code == 201
    room_id = room_resp.json()["id"]

    guest_resp = await async_client.post(
        f"/api/v1/properties/{prop_a}/guests",
        json={
            "room_id": room_id,
            "full_name": "Rent Cascade Test",
            "phone": "+919876543210",
            "monthly_rent": 5000,
            "joined_at": "2026-07-01",
        },
        headers=headers
    )
    assert guest_resp.status_code == 201
    guest_id = guest_resp.json()["id"]
    assert float(guest_resp.json()["monthly_rent"]) == 5000.0

    # Change the room's rent — and its capacity, which also shifts the per-guest
    # share the form would prefill next time.
    patch_resp = await async_client.patch(
        f"/api/v1/properties/{prop_a}/rooms/{room_id}",
        json={"default_rent": 20000, "capacity": 4},
        headers=headers
    )
    assert patch_resp.status_code == 200
    assert float(patch_resp.json()["default_rent"]) == 20000.0

    # The guest's rent is untouched.
    after = await async_client.get(f"/api/v1/properties/{prop_a}/guests/{guest_id}", headers=headers)
    assert after.status_code == 200
    assert float(after.json()["monthly_rent"]) == 5000.0

@pytest.mark.asyncio
async def test_rooms_cross_tenant_isolation(async_client: AsyncClient, setup_multitenant_rooms):
    prop_a = setup_multitenant_rooms["prop_a"]
    token_b = setup_multitenant_rooms["token_b"]
    headers = {"Authorization": f"Bearer {token_b}"}
    
    # User B (staff on Prop B) attempts to manipulate Prop A's rooms
    create_resp = await async_client.post(
        f"/api/v1/properties/{prop_a}/rooms",
        json={"room_number": "999", "room_type": "single", "capacity": 1},
        headers=headers
    )
    assert create_resp.status_code == 403
    
    list_resp = await async_client.get(f"/api/v1/properties/{prop_a}/rooms", headers=headers)
    assert list_resp.status_code == 403
    
    fake_room_id = str(uuid.uuid4())
    get_resp = await async_client.get(f"/api/v1/properties/{prop_a}/rooms/{fake_room_id}", headers=headers)
    assert get_resp.status_code == 403
    
    patch_resp = await async_client.patch(f"/api/v1/properties/{prop_a}/rooms/{fake_room_id}", json={}, headers=headers)
    assert patch_resp.status_code == 403
    
    del_resp = await async_client.delete(f"/api/v1/properties/{prop_a}/rooms/{fake_room_id}", headers=headers)
    assert del_resp.status_code == 403
