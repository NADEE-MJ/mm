"""initial schema

Revision ID: 0001_initial_schema
Revises:
Create Date: 2026-02-14 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0001_initial_schema"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("username", sa.String(), nullable=False),
        sa.Column("hashed_password", sa.String(), nullable=False),
        sa.Column("created_at", sa.Float(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=True),
        sa.Column("backup_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_index(op.f("ix_users_username"), "users", ["username"], unique=True)

    op.create_table(
        "movies",
        sa.Column("imdb_id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("tmdb_data", sa.Text(), nullable=True),
        sa.Column("omdb_data", sa.Text(), nullable=True),
        sa.Column("media_type", sa.String(), nullable=False, server_default="movie"),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("imdb_id", "user_id"),
    )
    op.create_index(op.f("ix_movies_imdb_id"), "movies", ["imdb_id"], unique=False)
    op.create_index("ix_movies_user_last_modified", "movies", ["user_id", "last_modified"], unique=False)

    op.create_table(
        "people",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("is_trusted", sa.Boolean(), nullable=True),
        sa.Column("color", sa.String(), nullable=True, server_default="#0a84ff"),
        sa.Column("emoji", sa.String(), nullable=True),
        sa.Column("quick_key", sa.String(), nullable=True),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "name", name="uq_person_name_per_user"),
    )
    op.create_index("ix_people_user_last_modified", "people", ["user_id", "last_modified"], unique=False)

    op.create_table(
        "custom_lists",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("color", sa.String(), nullable=True, server_default="#0a84ff"),
        sa.Column("icon", sa.String(), nullable=True, server_default="list"),
        sa.Column("position", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.Float(), nullable=True),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_custom_lists_user_last_modified",
        "custom_lists",
        ["user_id", "last_modified"],
        unique=False,
    )

    op.create_table(
        "movie_status",
        sa.Column("imdb_id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="toWatch"),
        sa.Column("custom_list_id", sa.String(), nullable=True),
        sa.CheckConstraint(
            "status IN ('toWatch', 'watched', 'deleted', 'custom')",
            name="check_status_values",
        ),
        sa.ForeignKeyConstraint(
            ["imdb_id", "user_id"],
            ["movies.imdb_id", "movies.user_id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("imdb_id", "user_id"),
    )
    op.create_index(
        "ix_movie_status_user_custom_list",
        "movie_status",
        ["user_id", "custom_list_id"],
        unique=False,
    )

    op.create_table(
        "recommendations",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("imdb_id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("person_id", sa.Integer(), nullable=False),
        sa.Column("date_recommended", sa.Float(), nullable=True),
        sa.Column("vote_type", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(
            ["imdb_id", "user_id"],
            ["movies.imdb_id", "movies.user_id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["person_id"], ["people.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("imdb_id", "user_id", "person_id", name="uq_recommendation_per_person"),
    )
    op.create_index(
        "ix_recommendations_user_person",
        "recommendations",
        ["user_id", "person_id"],
        unique=False,
    )
    op.create_index(
        "ix_recommendations_movie_user",
        "recommendations",
        ["imdb_id", "user_id"],
        unique=False,
    )

    op.create_table(
        "watch_history",
        sa.Column("imdb_id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("date_watched", sa.Float(), nullable=False),
        sa.Column("my_rating", sa.Float(), nullable=False),
        sa.CheckConstraint("my_rating >= 1.0 AND my_rating <= 10.0", name="check_rating_range"),
        sa.ForeignKeyConstraint(
            ["imdb_id", "user_id"],
            ["movies.imdb_id", "movies.user_id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("imdb_id", "user_id"),
    )


def downgrade() -> None:
    op.drop_table("watch_history")

    op.drop_index("ix_recommendations_movie_user", table_name="recommendations")
    op.drop_index("ix_recommendations_user_person", table_name="recommendations")
    op.drop_table("recommendations")

    op.drop_index("ix_movie_status_user_custom_list", table_name="movie_status")
    op.drop_table("movie_status")

    op.drop_index("ix_custom_lists_user_last_modified", table_name="custom_lists")
    op.drop_table("custom_lists")

    op.drop_index("ix_people_user_last_modified", table_name="people")
    op.drop_table("people")

    op.drop_index("ix_movies_user_last_modified", table_name="movies")
    op.drop_index(op.f("ix_movies_imdb_id"), table_name="movies")
    op.drop_table("movies")

    op.drop_index(op.f("ix_users_username"), table_name="users")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")
