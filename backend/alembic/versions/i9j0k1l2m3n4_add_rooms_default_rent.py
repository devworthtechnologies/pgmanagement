"""add default_rent to rooms

Revision ID: i9j0k1l2m3n4
Revises: h8i9j0k1l2m3
Create Date: 2026-07-25 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'i9j0k1l2m3n4'
down_revision: Union[str, None] = 'h8i9j0k1l2m3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Nullable on purpose: every existing room predates this column and must
    # keep working with no default rent set.
    op.add_column('rooms', sa.Column('default_rent', sa.Numeric(precision=10, scale=2), nullable=True))
    op.create_check_constraint(
        op.f('chk_rooms__default_rent'),
        'rooms',
        'default_rent IS NULL OR default_rent >= 0'
    )


def downgrade() -> None:
    op.drop_constraint(op.f('chk_rooms__default_rent'), 'rooms', type_='check')
    op.drop_column('rooms', 'default_rent')
