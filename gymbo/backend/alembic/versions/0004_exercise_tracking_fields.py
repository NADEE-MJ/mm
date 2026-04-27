"""add exercise info and tracking fields

Revision ID: 0004_exercise_tracking_fields
Revises: 0003_exercise_enum_ints
Create Date: 2026-02-24 00:00:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0004_exercise_tracking_fields"
down_revision: Union[str, Sequence[str], None] = "0003_exercise_enum_ints"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.add_column(sa.Column("video_url", sa.Text(), nullable=True))
        batch_op.add_column(sa.Column("goal_reps_min", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("goal_reps_max", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("show_highest_set", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("track_highest_set", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("highest_set_weight", sa.Float(), nullable=True))
        batch_op.add_column(sa.Column("highest_set_reps", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("show_one_rep_max", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("track_one_rep_max", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("one_rep_max", sa.Float(), nullable=True))

        batch_op.create_check_constraint(
            "ck_exercise_goal_reps_min_positive",
            "goal_reps_min IS NULL OR goal_reps_min >= 1",
        )
        batch_op.create_check_constraint(
            "ck_exercise_goal_reps_max_positive",
            "goal_reps_max IS NULL OR goal_reps_max >= 1",
        )
        batch_op.create_check_constraint(
            "ck_exercise_goal_reps_order",
            "goal_reps_min IS NULL OR goal_reps_max IS NULL OR goal_reps_min <= goal_reps_max",
        )
        batch_op.create_check_constraint(
            "ck_exercise_highest_set_weight_non_negative",
            "highest_set_weight IS NULL OR highest_set_weight >= 0",
        )
        batch_op.create_check_constraint(
            "ck_exercise_highest_set_reps_positive",
            "highest_set_reps IS NULL OR highest_set_reps >= 1",
        )
        batch_op.create_check_constraint(
            "ck_exercise_one_rep_max_non_negative",
            "one_rep_max IS NULL OR one_rep_max >= 0",
        )


def downgrade() -> None:
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercise_one_rep_max_non_negative", type_="check")
        batch_op.drop_constraint("ck_exercise_highest_set_reps_positive", type_="check")
        batch_op.drop_constraint("ck_exercise_highest_set_weight_non_negative", type_="check")
        batch_op.drop_constraint("ck_exercise_goal_reps_order", type_="check")
        batch_op.drop_constraint("ck_exercise_goal_reps_max_positive", type_="check")
        batch_op.drop_constraint("ck_exercise_goal_reps_min_positive", type_="check")

        batch_op.drop_column("one_rep_max")
        batch_op.drop_column("track_one_rep_max")
        batch_op.drop_column("show_one_rep_max")
        batch_op.drop_column("highest_set_reps")
        batch_op.drop_column("highest_set_weight")
        batch_op.drop_column("track_highest_set")
        batch_op.drop_column("show_highest_set")
        batch_op.drop_column("goal_reps_max")
        batch_op.drop_column("goal_reps_min")
        batch_op.drop_column("video_url")
