"""add poster_override column to movies

Revision ID: 0005_add_poster_override
Revises: 0004_add_notes_to_movie_status
Create Date: 2026-07-22 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0005_add_poster_override"
down_revision: Union[str, Sequence[str], None] = "0004_add_notes_to_movie_status"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("movies", recreate="always") as batch_op:
        batch_op.add_column(sa.Column("poster_override", sa.String(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("movies", recreate="always") as batch_op:
        batch_op.drop_column("poster_override")
