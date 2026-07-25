"""add void and correction columns to payments

Revision ID: k1l2m3n4o5p6
Revises: j0k1l2m3n4o5
Create Date: 2026-07-25 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'k1l2m3n4o5p6'
down_revision: Union[str, None] = 'j0k1l2m3n4o5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # deleted_at already exists (SoftDeleteMixin) and serves as the void
    # timestamp — these columns only add WHO voided, WHY, and which row a
    # replacement supersedes. All nullable: every pre-existing payment is
    # un-voided and corrects nothing.
    op.add_column('payments', sa.Column('voided_by', sa.Uuid(), nullable=True))
    op.add_column('payments', sa.Column('void_reason', sa.Text(), nullable=True))
    op.add_column('payments', sa.Column('corrects_payment_id', sa.Uuid(), nullable=True))

    op.create_foreign_key(
        op.f('fk_payments__voided_by__users'),
        'payments', 'users', ['voided_by'], ['id'], ondelete='SET NULL'
    )
    op.create_foreign_key(
        op.f('fk_payments__corrects_payment_id__payments'),
        'payments', 'payments', ['corrects_payment_id'], ['id'], ondelete='SET NULL'
    )


def downgrade() -> None:
    op.drop_constraint(op.f('fk_payments__corrects_payment_id__payments'), 'payments', type_='foreignkey')
    op.drop_constraint(op.f('fk_payments__voided_by__users'), 'payments', type_='foreignkey')
    op.drop_column('payments', 'corrects_payment_id')
    op.drop_column('payments', 'void_reason')
    op.drop_column('payments', 'voided_by')
