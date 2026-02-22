"""add movie rankings table

Revision ID: 0002_add_movie_rankings
Revises: 0001_initial_schema
Create Date: 2026-02-21 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0002_add_movie_rankings"
down_revision: Union[str, Sequence[str], None] = "0001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "movie_rankings",
        sa.Column("imdb_id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("score", sa.Float(), nullable=False),
        sa.Column("ranked_at", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(
            ["imdb_id", "user_id"],
            ["movies.imdb_id", "movies.user_id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("imdb_id", "user_id"),
        sa.UniqueConstraint("user_id", "position", name="uq_ranking_position_per_user"),
    )
    op.create_index(
        "ix_movie_rankings_user_position",
        "movie_rankings",
        ["user_id", "position"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_movie_rankings_user_position", table_name="movie_rankings")
    op.drop_table("movie_rankings")
