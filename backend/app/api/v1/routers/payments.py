import uuid
from datetime import date, datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.payment import (
    PaymentCreateRequest,
    PaymentCorrectRequest,
    PaymentResponse,
    PaymentVoidRequest,
)
from app.services.payment_service import PaymentService
from app.repositories.payment_repository import PaymentRepository
from app.api.v1.deps import (
    get_payment_service, 
    get_payment_repo, 
    get_db, 
    require_role,
    require_property_member
)
from app.models.property_member import PropertyMember
from app.core.exceptions import PaymentNotFoundError

router = APIRouter()

@router.post("", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def create_payment(
    property_id: uuid.UUID,
    request: PaymentCreateRequest,
    member: PropertyMember = Depends(require_role("staff")),
    payment_service: PaymentService = Depends(get_payment_service),
    db: AsyncSession = Depends(get_db)
):
    try:
        payment = await payment_service.record_payment(
            property_id=property_id,
            guest_id=request.guest_id,
            amount=request.amount,
            method=request.method,
            for_month=request.for_month,
            idempotency_key=request.idempotency_key,
            recorded_by=member.user_id,
            notes=request.notes
        )
        await db.commit()
        return payment
    except ValueError as e:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        await db.rollback()
        raise

@router.get("", response_model=List[PaymentResponse])
async def list_payments(
    property_id: uuid.UUID,
    guest_id: uuid.UUID | None = Query(None),
    month: str | None = Query(None, description="YYYY-MM formatted month"),
    include_voided: bool = Query(
        False,
        description="Include voided payments. For displaying ledger history only — "
                    "voided rows must never be summed into totals or balances."
    ),
    member: PropertyMember = Depends(require_property_member),
    payment_repo: PaymentRepository = Depends(get_payment_repo)
):
    for_month_date = None
    if month:
        try:
            # Safely parse YYYY-MM explicitly locking the date to the 1st
            parsed_date = datetime.strptime(month, "%Y-%m").date()
            for_month_date = date(parsed_date.year, parsed_date.month, 1)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, 
                detail="month must be in YYYY-MM format"
            )
            
    payments = await payment_repo.list_by_property(
        property_id=property_id,
        guest_id=guest_id,
        for_month=for_month_date,
        include_voided=include_voided
    )
    return payments

# There is deliberately NO DELETE route. A payment is corrected by voiding the
# wrong row and entering a replacement, so the ledger stays append-only and every
# reversal is attributed. Both routes below require MANAGER, not staff: the whole
# point is that whoever takes the cash can't also quietly undo the record of it.

@router.post("/{payment_id}/void", response_model=PaymentResponse)
async def void_payment(
    property_id: uuid.UUID,
    payment_id: uuid.UUID,
    request: PaymentVoidRequest,
    member: PropertyMember = Depends(require_role("manager")),
    payment_service: PaymentService = Depends(get_payment_service),
    payment_repo: PaymentRepository = Depends(get_payment_repo),
    db: AsyncSession = Depends(get_db)
):
    try:
        await payment_service.void_payment(
            property_id=property_id,
            payment_id=payment_id,
            voided_by=member.user_id,
            reason=request.reason
        )
        await db.commit()
    except PaymentNotFoundError as e:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        await db.rollback()
        raise

    # Re-read including voided rows so the response carries the void marker.
    voided = await payment_repo.list_by_property(property_id, include_voided=True)
    match = next((p for p in voided if p.id == payment_id), None)
    if not match:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    return match

@router.post("/{payment_id}/correct", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def correct_payment(
    property_id: uuid.UUID,
    payment_id: uuid.UUID,
    request: PaymentCorrectRequest,
    member: PropertyMember = Depends(require_role("manager")),
    payment_service: PaymentService = Depends(get_payment_service),
    db: AsyncSession = Depends(get_db)
):
    try:
        replacement = await payment_service.correct_payment(
            property_id=property_id,
            payment_id=payment_id,
            guest_id=request.guest_id,
            amount=request.amount,
            method=request.method,
            for_month=request.for_month,
            idempotency_key=request.idempotency_key,
            recorded_by=member.user_id,
            notes=request.notes,
            reason=request.reason
        )
        # Single commit for both halves — the void and the replacement land
        # together or not at all.
        await db.commit()
        return replacement
    except PaymentNotFoundError as e:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except ValueError as e:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        await db.rollback()
        raise
