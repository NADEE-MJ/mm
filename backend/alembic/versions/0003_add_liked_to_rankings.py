"""add liked column to movie_rankings

Revision ID: 0003_add_liked_to_rankings
Revises: 0002_add_movie_rankings
Create Date: 2026-02-21 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0003_add_liked_to_rankings"
down_revision: Union[str, Sequence[str], None] = "0002_add_movie_rankings"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop old position-only index before recreating the table
    op.drop_index("ix_movie_rankings_user_position", table_name="movie_rankings")

    # batch_alter_table handles SQLite's inability to ALTER constraints in-place
    with op.batch_alter_table("movie_rankings", recreate="always") as batch_op:
        batch_op.add_column(
            sa.Column("liked", sa.Boolean(), nullable=False, server_default="1")
        )
        batch_op.drop_constraint("uq_ranking_position_per_user", type_="unique")
        batch_op.create_unique_constraint(
            "uq_ranking_liked_position_per_user",
            ["user_id", "liked", "position"],
        )

    op.create_index(
        "ix_movie_rankings_user_liked_position",
        "movie_rankings",
        ["user_id", "liked", "position"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_movie_rankings_user_liked_position", table_name="movie_rankings")

    with op.batch_alter_table("movie_rankings", recreate="always") as batch_op:
        batch_op.drop_constraint("uq_ranking_liked_position_per_user", type_="unique")
        batch_op.drop_column("liked")
        batch_op.create_unique_constraint(
            "uq_ranking_position_per_user",
            ["user_id", "position"],
        )

    op.create_index(
        "ix_movie_rankings_user_position",
        "movie_rankings",
        ["user_id", "position"],
        unique=False,
    )
