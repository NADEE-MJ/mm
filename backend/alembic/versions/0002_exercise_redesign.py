"""exercise redesign fields and weight type normalization

Revision ID: 0002_exercise_redesign
Revises: 0001_initial_schema
Create Date: 2026-02-22 13:45:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0002_exercise_redesign"
down_revision: Union[str, Sequence[str], None] = "0001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


NEW_WEIGHT_TYPE_CHECK = (
    "weight_type IN ('bodyweight','dumbbells','plates','raw_weight','bands','time_based','distance')"
)
OLD_WEIGHT_TYPE_CHECK = "weight_type IN ('dumbbell','plates','machine','bodyweight','time_based','distance')"


def upgrade() -> None:
    op.add_column(
        "exercises",
        sa.Column("warmup_sets", sa.Integer(), nullable=False, server_default=sa.text("0")),
    )
    op.add_column(
        "exercises",
        sa.Column("accessories", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
    )

    op.add_column(
        "session_sets",
        sa.Column("is_warmup", sa.Boolean(), nullable=False, server_default=sa.text("0")),
    )
    op.add_column(
        "session_sets",
        sa.Column("used_accessories", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
    )
    op.add_column(
        "session_sets",
        sa.Column("band_color", sa.String(), nullable=True),
    )

    op.execute("UPDATE exercises SET weight_type = 'dumbbells' WHERE weight_type = 'dumbbell'")
    op.execute("UPDATE exercises SET weight_type = 'raw_weight' WHERE weight_type = 'machine'")

    with op.batch_alter_table("exercises", recreate="always") as batch_op:
        batch_op.drop_constraint("ck_exercise_weight_type", type_="check")
        batch_op.create_check_constraint("ck_exercise_weight_type", NEW_WEIGHT_TYPE_CHECK)
        batch_op.create_check_constraint("ck_exercise_warmup_sets_non_negative", "warmup_sets >= 0")

def downgrade() -> None:
    op.execute("UPDATE exercises SET weight_type = 'machine' WHERE weight_type = 'raw_weight'")
    op.execute("UPDATE exercises SET weight_type = 'dumbbell' WHERE weight_type = 'dumbbells'")
    op.execute("UPDATE exercises SET weight_type = 'bodyweight' WHERE weight_type = 'bands'")

    with op.batch_alter_table("exercises", recreate="always") as batch_op:
        batch_op.drop_constraint("ck_exercise_warmup_sets_non_negative", type_="check")
        batch_op.drop_constraint("ck_exercise_weight_type", type_="check")
        batch_op.create_check_constraint("ck_exercise_weight_type", OLD_WEIGHT_TYPE_CHECK)

    with op.batch_alter_table("session_sets") as batch_op:
        batch_op.drop_column("band_color")
        batch_op.drop_column("used_accessories")
        batch_op.drop_column("is_warmup")

    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_column("accessories")
        batch_op.drop_column("warmup_sets")
