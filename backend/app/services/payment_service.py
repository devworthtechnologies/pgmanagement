import uuid
from datetime import date
from typing import Any

from app.models.payment import Payment, PaymentMethod
from app.repositories.payment_repository import PaymentRepository
from app.repositories.guest_repository import GuestRepository
from app.core.exceptions import PaymentNotFoundError

class PaymentService:
    def __init__(self, payment_repo: PaymentRepository, guest_repo: GuestRepository):
        self.payment_repo = payment_repo
        self.guest_repo = guest_repo

    async def record_payment(
        self,
        property_id: uuid.UUID,
        guest_id: uuid.UUID,
        amount: float,
        method: str | PaymentMethod,
        for_month: date,
        idempotency_key: uuid.UUID,
        recorded_by: uuid.UUID | None,
        notes: str | None = None,
        corrects_payment_id: uuid.UUID | None = None
    ) -> Payment:
        # Check idempotency first (no-op return if exists)
        existing_payment = await self.payment_repo.get_by_idempotency_key(property_id, idempotency_key)
        if existing_payment:
            return existing_payment

        if amount <= 0:
            raise ValueError("Payment amount must be greater than 0.")
            
        # Ensure the date is mathematically the 1st of the month
        if for_month.day != 1:
            raise ValueError("for_month must be the first day of the month.")

        guest = await self.guest_repo.get_by_id(guest_id)
        if not guest or guest.property_id != property_id:
            raise ValueError("Guest not found or does not belong to this property.")

        payment = await self.payment_repo.create(
            property_id=property_id,
            guest_id=guest_id,
            amount=amount,
            method=PaymentMethod(method),
            for_month=for_month,
            idempotency_key=idempotency_key,
            recorded_by=recorded_by,
            notes=notes,
            corrects_payment_id=corrects_payment_id
        )
        return payment

    async def void_payment(
        self,
        property_id: uuid.UUID,
        payment_id: uuid.UUID,
        voided_by: uuid.UUID | None,
        reason: str | None = None
    ) -> Payment:
        """Voids a payment. The row stays in the ledger, marked and attributed —
        this is the only way to undo a payment, there is no edit and no delete."""
        payment = await self.payment_repo.get_by_id(payment_id)
        if not payment or payment.property_id != property_id:
            raise PaymentNotFoundError("Payment not found.")

        await self.payment_repo.void(payment_id, voided_by=voided_by, void_reason=reason)
        return payment

    async def correct_payment(
        self,
        property_id: uuid.UUID,
        payment_id: uuid.UUID,
        guest_id: uuid.UUID,
        amount: float,
        method: str | PaymentMethod,
        for_month: date,
        idempotency_key: uuid.UUID,
        recorded_by: uuid.UUID | None,
        notes: str | None = None,
        reason: str | None = None
    ) -> Payment:
        """
        Void the wrong row and write a replacement pointing back at it, both in
        the caller's transaction. The caller (router) owns the commit, so if the
        create half raises — bad guest, duplicate idempotency key, constraint
        violation — the rollback takes the void with it and the original payment
        is left untouched. Never half-applied.
        """
        original = await self.payment_repo.get_by_id(payment_id)
        if not original or original.property_id != property_id:
            raise PaymentNotFoundError("Payment not found.")

        await self.payment_repo.void(
            payment_id,
            voided_by=recorded_by,
            void_reason=reason or "Corrected"
        )

        return await self.record_payment(
            property_id=property_id,
            guest_id=guest_id,
            amount=amount,
            method=method,
            for_month=for_month,
            idempotency_key=idempotency_key,
            recorded_by=recorded_by,
            notes=notes,
            corrects_payment_id=payment_id
        )
