"""exercise fields migrated to integer enums

Revision ID: 0003_exercise_enum_ints
Revises: 0002_exercise_redesign
Create Date: 2026-02-23 00:00:00.000000

MuscleGroup bitmask:
  chest=1, back=2, shoulders=4, biceps=8, triceps=16,
  legs=32, core=64, cardio=128, full_body=256,
  plyometric=512, pilates=1024, mobility=2048

WeightType int:
  bodyweight=1, dumbbells=2, plates=3, raw_weight=4,
  bands=5, time_based=6, distance=7

ExerciseWorkoutType int:
  lifting=1, running=2, pilates=3, mobility=4,
  plyometric=5, hyrox=6, custom=7
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0003_exercise_enum_ints"
down_revision: Union[str, Sequence[str], None] = "0002_exercise_redesign"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Step 1: Add new integer columns
    op.add_column("exercises", sa.Column("muscle_groups", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("exercises", sa.Column("workout_type", sa.Integer(), nullable=True))
    op.add_column("exercises", sa.Column("weight_type_int", sa.Integer(), nullable=True))
    op.add_column("exercises", sa.Column("source_exercise_id", sa.String(), nullable=True))

    # Step 2: Populate muscle_groups bitmask from muscle_group string
    _MUSCLE_BITS = [
        ("chest", 1), ("back", 2), ("shoulders", 4), ("biceps", 8), ("triceps", 16),
        ("legs", 32), ("core", 64), ("cardio", 128), ("full_body", 256),
        ("plyometric", 512), ("pilates", 1024), ("mobility", 2048),
    ]
    for slug, bit in _MUSCLE_BITS:
        op.execute(f"UPDATE exercises SET muscle_groups = muscle_groups | {bit} WHERE muscle_group = '{slug}'")

    # Step 3: Populate workout_type int from workout_type_id FK via workout_types table
    _WORKOUT_TYPE_MAP = [
        ("lifting", 1), ("running", 2), ("pilates", 3), ("mobility", 4),
        ("plyometric", 5), ("hyrox", 6), ("custom", 7),
    ]
    for slug, val in _WORKOUT_TYPE_MAP:
        op.execute(
            f"UPDATE exercises SET workout_type = {val} "
            f"WHERE workout_type_id IN (SELECT id FROM workout_types WHERE slug = '{slug}')"
        )

    # Step 4: Populate weight_type_int from weight_type string
    _WEIGHT_MAP = [
        ("bodyweight", 1), ("dumbbells", 2), ("plates", 3), ("raw_weight", 4),
        ("bands", 5), ("time_based", 6), ("distance", 7),
    ]
    for slug, val in _WEIGHT_MAP:
        op.execute(f"UPDATE exercises SET weight_type_int = {val} WHERE weight_type = '{slug}'")
    # Default to bodyweight (1) for any unrecognised strings
    op.execute("UPDATE exercises SET weight_type_int = 1 WHERE weight_type_int IS NULL")

    # Step 5: Recreate exercises table dropping old string columns
    with op.batch_alter_table("exercises", recreate="always") as batch_op:
        batch_op.drop_column("muscle_group")
        batch_op.drop_column("workout_type_id")
        batch_op.drop_column("weight_type")
        # Drop old check constraints (ignore errors if already absent)
        for constraint in ("ck_exercise_weight_type", "ck_exercise_warmup_sets_non_negative"):
            try:
                batch_op.drop_constraint(constraint, type_="check")
            except Exception:
                pass
        # Re-add warmup_sets non-negative constraint
        batch_op.create_check_constraint("ck_exercise_warmup_sets_non_negative", "warmup_sets >= 0")

    # Step 6: Rename weight_type_int → weight_type
    with op.batch_alter_table("exercises", recreate="always") as batch_op:
        batch_op.alter_column("weight_type_int", new_column_name="weight_type")


def downgrade() -> None:
    # Add back string columns
    op.add_column("exercises", sa.Column("muscle_group", sa.String(), nullable=True))
    op.add_column("exercises", sa.Column("workout_type_id", sa.String(), nullable=True))
    op.add_column("exercises", sa.Column("weight_type_str", sa.String(), nullable=True))

    # Reverse weight_type int → string
    _WEIGHT_MAP_REV = [
        (1, "bodyweight"), (2, "dumbbells"), (3, "plates"), (4, "raw_weight"),
        (5, "bands"), (6, "time_based"), (7, "distance"),
    ]
    for val, slug in _WEIGHT_MAP_REV:
        op.execute(f"UPDATE exercises SET weight_type_str = '{slug}' WHERE weight_type = {val}")

    # Reverse workout_type int → workout_type_id (best effort; system exercises only)
    _WORKOUT_MAP_REV = [
        (1, "lifting"), (2, "running"), (3, "pilates"), (4, "mobility"),
        (5, "plyometric"), (6, "hyrox"), (7, "custom"),
    ]
    for val, slug in _WORKOUT_MAP_REV:
        op.execute(
            f"UPDATE exercises SET workout_type_id = "
            f"(SELECT id FROM workout_types WHERE slug = '{slug}' LIMIT 1) "
            f"WHERE workout_type = {val}"
        )

    # Reverse muscle_groups bitmask → single muscle_group string (largest bit wins)
    _MUSCLE_REV = sorted([
        (2048, "mobility"), (1024, "pilates"), (512, "plyometric"), (256, "full_body"),
        (128, "cardio"), (64, "core"), (32, "legs"), (16, "triceps"),
        (8, "biceps"), (4, "shoulders"), (2, "back"), (1, "chest"),
    ], reverse=True)
    for bit, slug in _MUSCLE_REV:
        op.execute(f"UPDATE exercises SET muscle_group = '{slug}' WHERE muscle_groups & {bit} != 0 AND muscle_group IS NULL")

    with op.batch_alter_table("exercises", recreate="always") as batch_op:
        batch_op.drop_column("muscle_groups")
        batch_op.drop_column("workout_type")
        batch_op.drop_column("weight_type")
        batch_op.drop_column("source_exercise_id")
        try:
            batch_op.drop_constraint("ck_exercise_warmup_sets_non_negative", type_="check")
        except Exception:
            pass
        batch_op.create_check_constraint(
            "ck_exercise_weight_type",
            "weight_type_str IN ('bodyweight','dumbbells','plates','raw_weight','bands','time_based','distance')",
        )
        batch_op.create_check_constraint("ck_exercise_warmup_sets_non_negative", "warmup_sets >= 0")

    with op.batch_alter_table("exercises", recreate="always") as batch_op:
        batch_op.alter_column("weight_type_str", new_column_name="weight_type")
