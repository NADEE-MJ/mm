"""add notes column to movie_status

Revision ID: 0004_add_notes_to_movie_status
Revises: 0003_add_liked_to_rankings
Create Date: 2026-07-22 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0004_add_notes_to_movie_status"
down_revision: Union[str, Sequence[str], None] = "0003_add_liked_to_rankings"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("movie_status", recreate="always") as batch_op:
        batch_op.add_column(sa.Column("notes", sa.Text(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("movie_status", recreate="always") as batch_op:
        batch_op.drop_column("notes")
