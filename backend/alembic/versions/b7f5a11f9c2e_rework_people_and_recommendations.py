"""rework people and recommendations schema

Revision ID: b7f5a11f9c2e
Revises: 6f9f20fb7d19
Create Date: 2026-02-13 10:00:00.000000

"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b7f5a11f9c2e"
down_revision: Union[str, Sequence[str], None] = "6f9f20fb7d19"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "sqlite":
        op.execute(
            """
            CREATE TABLE people_new (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                name VARCHAR NOT NULL,
                user_id VARCHAR NOT NULL,
                is_trusted BOOLEAN,
                color VARCHAR,
                emoji VARCHAR,
                last_modified FLOAT,
                FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
            )
            """
        )
        op.execute(
            """
            INSERT INTO people_new (name, user_id, is_trusted, color, emoji, last_modified)
            SELECT name, user_id, is_trusted, COALESCE(color, '#0a84ff'), emoji, last_modified
            FROM people
            """
        )
        # Ensure a person record exists for every historical recommendation name.
        op.execute(
            """
            INSERT INTO people_new (name, user_id, is_trusted, color, emoji, last_modified)
            SELECT DISTINCT r.person, r.user_id, 0, '#0a84ff', NULL, strftime('%s','now')
            FROM recommendations r
            LEFT JOIN people_new p
              ON p.user_id = r.user_id AND p.name = r.person
            WHERE p.id IS NULL AND r.person IS NOT NULL
            """
        )
        op.execute("CREATE UNIQUE INDEX uq_person_name_per_user_new ON people_new(user_id, name)")

        op.execute(
            """
            CREATE TABLE recommendations_new (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                imdb_id VARCHAR NOT NULL,
                user_id VARCHAR NOT NULL,
                person_id INTEGER NOT NULL,
                date_recommended FLOAT,
                vote_type BOOLEAN NOT NULL DEFAULT 1,
                FOREIGN KEY(imdb_id, user_id) REFERENCES movies (imdb_id, user_id) ON DELETE CASCADE,
                FOREIGN KEY(person_id) REFERENCES people_new (id) ON DELETE CASCADE
            )
            """
        )

        op.execute(
            """
            WITH ranked AS (
                SELECT
                    r.id,
                    r.imdb_id,
                    r.user_id,
                    p.id AS person_id,
                    r.date_recommended,
                    CASE
                        WHEN lower(COALESCE(r.vote_type, 'upvote')) IN ('upvote', '1', 'true', 't', 'yes')
                            THEN 1
                        ELSE 0
                    END AS vote_type_bool,
                    ROW_NUMBER() OVER (
                        PARTITION BY r.imdb_id, r.user_id, p.id
                        ORDER BY COALESCE(r.date_recommended, 0) DESC, r.id DESC
                    ) AS rn
                FROM recommendations r
                JOIN people_new p
                  ON p.user_id = r.user_id AND p.name = r.person
            )
            INSERT INTO recommendations_new (id, imdb_id, user_id, person_id, date_recommended, vote_type)
            SELECT id, imdb_id, user_id, person_id, date_recommended, vote_type_bool
            FROM ranked
            WHERE rn = 1
            """
        )
        op.execute(
            "CREATE UNIQUE INDEX uq_recommendation_per_person_new ON recommendations_new(imdb_id, user_id, person_id)"
        )
        op.execute("CREATE INDEX ix_recommendations_user_person_new ON recommendations_new(user_id, person_id)")
        op.execute("CREATE INDEX ix_recommendations_movie_user_new ON recommendations_new(imdb_id, user_id)")

        op.execute("DROP TABLE recommendations")
        op.execute("DROP TABLE people")
        op.execute("ALTER TABLE people_new RENAME TO people")
        op.execute("ALTER TABLE recommendations_new RENAME TO recommendations")

        op.execute("DROP INDEX IF EXISTS uq_person_name_per_user_new")
        op.execute("DROP INDEX IF EXISTS uq_recommendation_per_person_new")
        op.execute("DROP INDEX IF EXISTS ix_recommendations_user_person_new")
        op.execute("DROP INDEX IF EXISTS ix_recommendations_movie_user_new")

        op.execute("CREATE UNIQUE INDEX uq_person_name_per_user ON people(user_id, name)")
        op.execute(
            "CREATE UNIQUE INDEX uq_recommendation_per_person ON recommendations(imdb_id, user_id, person_id)"
        )
        op.execute("CREATE INDEX ix_recommendations_user_person ON recommendations(user_id, person_id)")
        op.execute("CREATE INDEX ix_recommendations_movie_user ON recommendations(imdb_id, user_id)")
        return

    # Non-SQLite fallback (expected primarily for local SQLite usage).
    op.add_column("people", sa.Column("id", sa.Integer(), autoincrement=True, nullable=True))
    op.create_unique_constraint("uq_person_name_per_user", "people", ["user_id", "name"])
    op.add_column("recommendations", sa.Column("person_id", sa.Integer(), nullable=True))
    op.add_column("recommendations", sa.Column("vote_type_bool", sa.Boolean(), nullable=False, server_default=sa.true()))


def downgrade() -> None:
    """Downgrade schema."""
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "sqlite":
        op.execute(
            """
            CREATE TABLE people_old (
                name VARCHAR NOT NULL,
                user_id VARCHAR NOT NULL,
                is_trusted BOOLEAN,
                is_default BOOLEAN,
                color VARCHAR,
                emoji VARCHAR,
                last_modified FLOAT,
                PRIMARY KEY (name, user_id),
                FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
            )
            """
        )
        op.execute(
            """
            INSERT INTO people_old (name, user_id, is_trusted, is_default, color, emoji, last_modified)
            SELECT name, user_id, is_trusted, 0, color, emoji, last_modified
            FROM people
            """
        )

        op.execute(
            """
            CREATE TABLE recommendations_old (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                imdb_id VARCHAR NOT NULL,
                user_id VARCHAR NOT NULL,
                person VARCHAR NOT NULL,
                date_recommended FLOAT,
                vote_type VARCHAR DEFAULT 'upvote',
                FOREIGN KEY(imdb_id, user_id) REFERENCES movies (imdb_id, user_id) ON DELETE CASCADE
            )
            """
        )
        op.execute(
            """
            INSERT INTO recommendations_old (id, imdb_id, user_id, person, date_recommended, vote_type)
            SELECT
                r.id,
                r.imdb_id,
                r.user_id,
                p.name,
                r.date_recommended,
                CASE WHEN r.vote_type = 1 THEN 'upvote' ELSE 'downvote' END
            FROM recommendations r
            JOIN people p ON p.id = r.person_id
            """
        )

        op.execute("DROP TABLE recommendations")
        op.execute("DROP TABLE people")
        op.execute("ALTER TABLE people_old RENAME TO people")
        op.execute("ALTER TABLE recommendations_old RENAME TO recommendations")
        return

    op.drop_column("recommendations", "vote_type_bool")
    op.drop_column("recommendations", "person_id")
    op.drop_constraint("uq_person_name_per_user", "people", type_="unique")
    op.drop_column("people", "id")
