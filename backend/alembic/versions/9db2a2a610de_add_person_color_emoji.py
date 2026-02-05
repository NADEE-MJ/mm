"""add person color emoji

Revision ID: 9db2a2a610de
Revises: ffede2f75426
Create Date: 2026-02-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "9db2a2a610de"
down_revision: Union[str, Sequence[str], None] = "ffede2f75426"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add color and emoji columns to people."""
    op.add_column("people", sa.Column("color", sa.String(), nullable=True))
    op.add_column("people", sa.Column("emoji", sa.String(), nullable=True))
    op.execute("UPDATE people SET color = '#0a84ff' WHERE color IS NULL")


def downgrade() -> None:
    """Remove color and emoji columns from people."""
    op.drop_column("people", "emoji")
    op.drop_column("people", "color")
