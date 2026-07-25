"""add moved_out_at >= joined_at check to guests

Revision ID: j0k1l2m3n4o5
Revises: i9j0k1l2m3n4
Create Date: 2026-07-25 09:15:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'j0k1l2m3n4o5'
down_revision: Union[str, None] = 'i9j0k1l2m3n4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # No data cleanup step on purpose: joined_at was hardcoded to "today" until
    # now, so no existing row can move out before it joined. If this fails on a
    # real database, that means something else wrote a bad row and the right
    # move is to look at it, not to silently rewrite it.
    op.create_check_constraint(
        op.f('chk_guests__moved_out_after_joined'),
        'guests',
        'moved_out_at IS NULL OR moved_out_at >= joined_at'
    )


def downgrade() -> None:
    op.drop_constraint(op.f('chk_guests__moved_out_after_joined'), 'guests', type_='check')
