"""add_vote_type_to_recommendations

Revision ID: 27943261bbb0
Revises: 9db2a2a610de
Create Date: 2026-02-05 17:42:37.941517

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '27943261bbb0'
down_revision: Union[str, Sequence[str], None] = '9db2a2a610de'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add vote_type column with default 'upvote'
    op.add_column('recommendations', sa.Column('vote_type', sa.String(), nullable=False, server_default='upvote'))


def downgrade() -> None:
    """Downgrade schema."""
    # Remove vote_type column
    op.drop_column('recommendations', 'vote_type')
