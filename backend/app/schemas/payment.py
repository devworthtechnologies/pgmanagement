import uuid
from datetime import date, datetime
from pydantic import BaseModel, Field
from app.models.payment import PaymentMethod

class PaymentCreateRequest(BaseModel):
    guest_id: uuid.UUID
    amount: float = Field(..., gt=0)
    method: PaymentMethod
    for_month: date
    idempotency_key: uuid.UUID
    notes: str | None = None

class PaymentVoidRequest(BaseModel):
    reason: str | None = None

class PaymentCorrectRequest(PaymentCreateRequest):
    """Same fields as recording a payment — the corrected values, plus a fresh
    idempotency_key — with an optional reason recorded against the voided row."""
    reason: str | None = None

class PaymentResponse(BaseModel):
    id: uuid.UUID
    property_id: uuid.UUID
    guest_id: uuid.UUID
    amount: float
    method: PaymentMethod
    for_month: date
    paid_at: datetime
    recorded_by: uuid.UUID | None
    idempotency_key: uuid.UUID
    notes: str | None
    created_at: datetime
    updated_at: datetime

    # Void marker and provenance. `deleted_at` non-null means voided — it is the
    # void timestamp, not a separate soft-delete concept.
    deleted_at: datetime | None
    voided_by: uuid.UUID | None
    void_reason: str | None
    corrects_payment_id: uuid.UUID | None

    class Config:
        from_attributes = True
