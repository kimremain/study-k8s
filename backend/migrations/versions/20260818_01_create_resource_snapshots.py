"""Create resource snapshots table.

Revision ID: 20260818_01
Revises:
Create Date: 2026-08-18
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260818_01"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "resource_snapshots",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("namespace", sa.String(length=253), nullable=False),
        sa.Column("kind", sa.String(length=63), nullable=False),
        sa.Column("name", sa.String(length=253), nullable=False),
        sa.Column("status", sa.String(length=63), nullable=False),
        sa.Column(
            "observed_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_resource_snapshots_identity_observed_at",
        "resource_snapshots",
        ["namespace", "kind", "name", "observed_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_resource_snapshots_identity_observed_at",
        table_name="resource_snapshots",
    )
    op.drop_table("resource_snapshots")
