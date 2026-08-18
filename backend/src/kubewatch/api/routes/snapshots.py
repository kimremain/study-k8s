from datetime import datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from kubewatch.db.models import ResourceSnapshot
from kubewatch.db.session import get_db_session

router = APIRouter(prefix="/api/v1/resource-snapshots", tags=["resource snapshots"])


class ResourceSnapshotCreate(BaseModel):
    namespace: str = Field(min_length=1, max_length=253)
    kind: str = Field(min_length=1, max_length=63)
    name: str = Field(min_length=1, max_length=253)
    status: str = Field(min_length=1, max_length=63)
    payload: dict[str, Any] = Field(default_factory=dict)


class ResourceSnapshotResponse(ResourceSnapshotCreate):
    model_config = ConfigDict(from_attributes=True)

    id: int
    observed_at: datetime


@router.post(
    "",
    response_model=ResourceSnapshotResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_resource_snapshot(
    snapshot: ResourceSnapshotCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> ResourceSnapshot:
    row = ResourceSnapshot(**snapshot.model_dump())
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return row


@router.get("", response_model=list[ResourceSnapshotResponse])
async def list_resource_snapshots(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    limit: int = Query(default=50, ge=1, le=200),
) -> list[ResourceSnapshot]:
    result = await session.scalars(
        select(ResourceSnapshot).order_by(ResourceSnapshot.observed_at.desc()).limit(limit)
    )
    return list(result)
