"""add last_modified to people and custom lists

Revision ID: 6f9f20fb7d19
Revises: 27943261bbb0
Create Date: 2026-02-07 13:35:00.000000

"""

from __future__ import annotations

import time
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "6f9f20fb7d19"
down_revision: Union[str, Sequence[str], None] = "27943261bbb0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    now = time.time()
    op.add_column("people", sa.Column("last_modified", sa.Float(), nullable=True))
    op.add_column("custom_lists", sa.Column("last_modified", sa.Float(), nullable=True))

    op.execute(f"UPDATE people SET last_modified = {now} WHERE last_modified IS NULL")
    op.execute(f"UPDATE custom_lists SET last_modified = {now} WHERE last_modified IS NULL")


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("custom_lists", "last_modified")
    op.drop_column("people", "last_modified")
