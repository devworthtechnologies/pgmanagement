import uuid
from datetime import date, datetime, timezone
from typing import Any
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payment import Payment

class PaymentRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, **fields: Any) -> Payment:
        payment = Payment(**fields)
        self.session.add(payment)
        await self.session.flush()
        return payment

    async def get_by_id(self, payment_id: uuid.UUID) -> Payment | None:
        stmt = select(Payment).where(
            Payment.id == payment_id,
            Payment.deleted_at.is_(None)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_idempotency_key(self, property_id: uuid.UUID, idempotency_key: uuid.UUID) -> Payment | None:
        stmt = select(Payment).where(
            Payment.property_id == property_id,
            Payment.idempotency_key == idempotency_key,
            Payment.deleted_at.is_(None)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_by_property(
        self,
        property_id: uuid.UUID,
        guest_id: uuid.UUID | None = None,
        for_month: date | None = None,
        include_voided: bool = False
    ) -> list[Payment]:
        stmt = select(Payment).where(Payment.property_id == property_id)

        # Voided rows are excluded by DEFAULT, and every money path relies on
        # that: stats_service sums whatever this returns into collected totals
        # and per-guest balances. Passing include_voided=True is for showing
        # ledger history in the UI only — never for arithmetic.
        if not include_voided:
            stmt = stmt.where(Payment.deleted_at.is_(None))

        if guest_id is not None:
            stmt = stmt.where(Payment.guest_id == guest_id)

        if for_month is not None:
            stmt = stmt.where(Payment.for_month == for_month)

        stmt = stmt.order_by(Payment.for_month.desc(), Payment.paid_at.desc())

        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def void(
        self,
        payment_id: uuid.UUID,
        voided_by: uuid.UUID | None,
        void_reason: str | None
    ) -> None:
        """Marks a payment void. `deleted_at` doubles as the void timestamp.
        The `deleted_at IS NULL` guard makes this a no-op on an already-voided
        row rather than silently re-stamping who voided it."""
        stmt = (
            update(Payment)
            .where(Payment.id == payment_id, Payment.deleted_at.is_(None))
            .values(
                deleted_at=datetime.now(timezone.utc),
                voided_by=voided_by,
                void_reason=void_reason,
            )
        )
        await self.session.execute(stmt)
        await self.session.flush()
