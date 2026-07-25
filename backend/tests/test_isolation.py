import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.property import Property
from app.models.property_member import PropertyMember, PropertyRole

# NOTE: the two tests below are about TRANSACTION isolation between pytest runs.
# The tenant-isolation test at the bottom of this file is a different thing
# entirely — don't read the file name as covering only one of them.

async def test_isolation_insert(db_session: AsyncSession):
    # Postgres rolls back DDL as well, so creating a table is safe here
    await db_session.execute(text("""
        CREATE TABLE IF NOT EXISTS isolation_test (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL
        )
    """))
    await db_session.execute(text("INSERT INTO isolation_test (name) VALUES ('isolated')"))
    await db_session.commit() # This commits to the savepoint, not the DB
    
    result = await db_session.execute(text("SELECT COUNT(*) FROM isolation_test"))
    assert result.scalar() == 1

async def test_isolation_assert_empty(db_session: AsyncSession):
    # This test runs after test_isolation_insert. If rollback works, the table won't exist.
    # Recreate it to prove it's empty in this new transaction context.
    await db_session.execute(text("""
        CREATE TABLE IF NOT EXISTS isolation_test (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL
        )
    """))
    
    result = await db_session.execute(text("SELECT COUNT(*) FROM isolation_test"))
    assert result.scalar() == 0


@pytest.fixture
async def user_with_two_properties(db_session: AsyncSession):
    from app.core.security import create_access_token

    owner = User(id=uuid.uuid4(), email="two_pgs@ex.com", password_hash="h", full_name="Multi PG Owner", is_active=True)
    db_session.add(owner)
    await db_session.flush()

    prop_a = Property(id=uuid.uuid4(), owner_id=owner.id, name="PG A")
    prop_b = Property(id=uuid.uuid4(), owner_id=owner.id, name="PG B")
    db_session.add_all([prop_a, prop_b])
    await db_session.flush()

    db_session.add_all([
        PropertyMember(id=uuid.uuid4(), property_id=prop_a.id, user_id=owner.id, role=PropertyRole.OWNER),
        PropertyMember(id=uuid.uuid4(), property_id=prop_b.id, user_id=owner.id, role=PropertyRole.OWNER),
    ])
    await db_session.commit()

    return {"prop_a": prop_a.id, "prop_b": prop_b.id, "token": create_access_token(owner.id)}


@pytest.mark.asyncio
async def test_tenant_isolation_for_a_member_of_two_properties(
    async_client: AsyncClient, user_with_two_properties
):
    """
    Tenant isolation for a caller who is legitimately a member of BOTH
    properties. The existing cross-tenant tests (test_role_deps.py,
    test_rooms_api.py) cover the *non*-member case, where a 403 from
    require_property_member is what stops the request — that check can't help
    here, because this caller is authorized for both. Only correct query
    scoping keeps the two PGs apart, which is exactly what the app's multi-PG
    switcher now depends on.
    """
    prop_a = user_with_two_properties["prop_a"]
    prop_b = user_with_two_properties["prop_b"]
    headers = {"Authorization": f"Bearer {user_with_two_properties['token']}"}

    async def seed(prop_id, room_number, guest_name, amount):
        room = await async_client.post(
            f"/api/v1/properties/{prop_id}/rooms",
            json={"room_number": room_number, "room_type": "double", "capacity": 2},
            headers=headers
        )
        assert room.status_code == 201
        guest = await async_client.post(
            f"/api/v1/properties/{prop_id}/guests",
            json={
                "room_id": room.json()["id"],
                "full_name": guest_name,
                "phone": "9876543210",
                "monthly_rent": 5000,
                "joined_at": "2026-01-01",
            },
            headers=headers
        )
        assert guest.status_code == 201
        payment = await async_client.post(
            f"/api/v1/properties/{prop_id}/payments",
            json={
                "guest_id": guest.json()["id"],
                "amount": amount,
                "method": "upi",
                "for_month": "2026-07-01",
                "idempotency_key": str(uuid.uuid4()),
            },
            headers=headers
        )
        assert payment.status_code == 201
        return {"room": room.json()["id"], "guest": guest.json()["id"], "payment": payment.json()["id"]}

    a = await seed(prop_a, "A-101", "Guest In A", 5000)
    b = await seed(prop_b, "B-201", "Guest In B", 7000)

    # Every list endpoint returns only its own property's rows.
    for prop_id, mine, theirs in ((prop_a, a, b), (prop_b, b, a)):
        rooms = await async_client.get(f"/api/v1/properties/{prop_id}/rooms", headers=headers)
        assert rooms.status_code == 200
        room_ids = {r["id"] for r in rooms.json()}
        assert room_ids == {mine["room"]}
        assert theirs["room"] not in room_ids
        assert all(r["property_id"] == str(prop_id) for r in rooms.json())

        guests = await async_client.get(f"/api/v1/properties/{prop_id}/guests", headers=headers)
        assert guests.status_code == 200
        guest_ids = {g["id"] for g in guests.json()}
        assert guest_ids == {mine["guest"]}
        assert theirs["guest"] not in guest_ids
        assert all(g["property_id"] == str(prop_id) for g in guests.json())

        payments = await async_client.get(f"/api/v1/properties/{prop_id}/payments", headers=headers)
        assert payments.status_code == 200
        payment_ids = {p["id"] for p in payments.json()}
        assert payment_ids == {mine["payment"]}
        assert theirs["payment"] not in payment_ids
        assert all(p["property_id"] == str(prop_id) for p in payments.json())

    # Nor can one property's path be used to reach the other's rows by id — the
    # caller has a valid membership for both, so this is purely down to the
    # routes checking that the row actually belongs to the property in the path.
    cross_room = await async_client.get(f"/api/v1/properties/{prop_a}/rooms/{b['room']}", headers=headers)
    assert cross_room.status_code == 404
    cross_guest = await async_client.get(f"/api/v1/properties/{prop_a}/guests/{b['guest']}", headers=headers)
    assert cross_guest.status_code == 404

    # And the dashboard aggregates don't bleed either — A collected 5000, not 12000.
    stats_a = await async_client.get(
        f"/api/v1/properties/{prop_a}/stats/dashboard?month=2026-07", headers=headers
    )
    assert stats_a.status_code == 200
    assert float(stats_a.json()["collected_this_month"]) == 5000.0
    assert stats_a.json()["total_rooms"] == 1
    assert stats_a.json()["active_guests"] == 1
