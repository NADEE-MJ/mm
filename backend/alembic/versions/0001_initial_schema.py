"""initial schema

Revision ID: 0001_initial_schema
Revises: 
Create Date: 2026-02-22 00:00:00.000000
"""

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
        sa.Column("backup_enabled", sa.Boolean(), nullable=False),
        sa.Column("unit_preference", sa.String(), nullable=False),
        sa.Column("barbell_weight", sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_index(op.f("ix_users_username"), "users", ["username"], unique=True)

    op.create_table(
        "workout_types",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("slug", sa.String(), nullable=False),
        sa.Column("icon", sa.String(), nullable=True),
        sa.Column("color", sa.String(), nullable=True),
        sa.Column("is_system", sa.Boolean(), nullable=False),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "slug", name="uq_workout_type_user_slug"),
    )
    op.create_index("ix_workout_types_user_last_modified", "workout_types", ["user_id", "last_modified"], unique=False)

    op.create_table(
        "exercises",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("muscle_group", sa.String(), nullable=True),
        sa.Column("workout_type_id", sa.String(), nullable=True),
        sa.Column("weight_type", sa.String(), nullable=False),
        sa.Column("is_system", sa.Boolean(), nullable=False),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.CheckConstraint(
            "weight_type IN ('dumbbell','plates','machine','bodyweight','time_based','distance')",
            name="ck_exercise_weight_type",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["workout_type_id"], ["workout_types.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_exercises_user_last_modified", "exercises", ["user_id", "last_modified"], unique=False)

    op.create_table(
        "workout_templates",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("workout_type_id", sa.String(), nullable=True),
        sa.Column("is_system", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.Float(), nullable=True),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["workout_type_id"], ["workout_types.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_templates_user_last_modified", "workout_templates", ["user_id", "last_modified"], unique=False)

    op.create_table(
        "workout_template_exercises",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("template_id", sa.String(), nullable=False),
        sa.Column("exercise_id", sa.String(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("default_sets", sa.Integer(), nullable=True),
        sa.Column("default_reps", sa.Integer(), nullable=True),
        sa.Column("default_weight", sa.Float(), nullable=True),
        sa.Column("default_duration_secs", sa.Integer(), nullable=True),
        sa.Column("default_distance", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["template_id"], ["workout_templates.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["exercise_id"], ["exercises.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("template_id", "position", name="uq_template_position"),
    )
    op.create_index("ix_template_exercises_template", "workout_template_exercises", ["template_id"], unique=False)

    op.create_table(
        "weekly_schedule",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("day_of_week", sa.Integer(), nullable=False),
        sa.Column("template_id", sa.String(), nullable=True),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.CheckConstraint("day_of_week >= 0 AND day_of_week <= 6", name="ck_weekly_schedule_day"),
        sa.ForeignKeyConstraint(["template_id"], ["workout_templates.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_weekly_schedule_user_day", "weekly_schedule", ["user_id", "day_of_week"], unique=False)
    op.create_index("ix_weekly_schedule_user_last_modified", "weekly_schedule", ["user_id", "last_modified"], unique=False)

    op.create_table(
        "workout_sessions",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("template_id", sa.String(), nullable=True),
        sa.Column("date", sa.Float(), nullable=False),
        sa.Column("started_at", sa.Float(), nullable=True),
        sa.Column("finished_at", sa.Float(), nullable=True),
        sa.Column("duration_secs", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.CheckConstraint("status IN ('in_progress','completed','abandoned')", name="ck_session_status"),
        sa.ForeignKeyConstraint(["template_id"], ["workout_templates.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_sessions_user_date", "workout_sessions", ["user_id", "date"], unique=False)
    op.create_index("ix_sessions_user_last_modified", "workout_sessions", ["user_id", "last_modified"], unique=False)

    op.create_table(
        "session_exercises",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("exercise_id", sa.String(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["exercise_id"], ["exercises.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id"], ["workout_sessions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("session_id", "position", name="uq_session_exercise_position"),
    )
    op.create_index("ix_session_exercises_session", "session_exercises", ["session_id"], unique=False)

    op.create_table(
        "session_sets",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("session_exercise_id", sa.String(), nullable=False),
        sa.Column("set_number", sa.Integer(), nullable=False),
        sa.Column("reps", sa.Integer(), nullable=True),
        sa.Column("weight", sa.Float(), nullable=True),
        sa.Column("duration_secs", sa.Integer(), nullable=True),
        sa.Column("distance", sa.Float(), nullable=True),
        sa.Column("completed", sa.Boolean(), nullable=False),
        sa.Column("last_modified", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["session_exercise_id"], ["session_exercises.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("session_exercise_id", "set_number", name="uq_session_set_number"),
    )
    op.create_index("ix_session_sets_exercise", "session_sets", ["session_exercise_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_session_sets_exercise", table_name="session_sets")
    op.drop_table("session_sets")

    op.drop_index("ix_session_exercises_session", table_name="session_exercises")
    op.drop_table("session_exercises")

    op.drop_index("ix_sessions_user_last_modified", table_name="workout_sessions")
    op.drop_index("ix_sessions_user_date", table_name="workout_sessions")
    op.drop_table("workout_sessions")

    op.drop_index("ix_weekly_schedule_user_last_modified", table_name="weekly_schedule")
    op.drop_index("ix_weekly_schedule_user_day", table_name="weekly_schedule")
    op.drop_table("weekly_schedule")

    op.drop_index("ix_template_exercises_template", table_name="workout_template_exercises")
    op.drop_table("workout_template_exercises")

    op.drop_index("ix_templates_user_last_modified", table_name="workout_templates")
    op.drop_table("workout_templates")

    op.drop_index("ix_exercises_user_last_modified", table_name="exercises")
    op.drop_table("exercises")

    op.drop_index("ix_workout_types_user_last_modified", table_name="workout_types")
    op.drop_table("workout_types")

    op.drop_index(op.f("ix_users_username"), table_name="users")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")
