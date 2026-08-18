from datetime import datetime
from typing import Any

from sqlalchemy import JSON, DateTime, Index, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class ResourceSnapshot(Base):
    __tablename__ = "resource_snapshots"
    __table_args__ = (
        Index(
            "ix_resource_snapshots_identity_observed_at",
            "namespace",
            "kind",
            "name",
            "observed_at",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    namespace: Mapped[str] = mapped_column(String(253))
    kind: Mapped[str] = mapped_column(String(63))
    name: Mapped[str] = mapped_column(String(253))
    status: Mapped[str] = mapped_column(String(63))
    observed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
