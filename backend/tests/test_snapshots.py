from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import pytest
from asgi_lifespan import LifespanManager
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from kubewatch.api.app import create_app
from kubewatch.db.models import Base
from kubewatch.db.session import database_is_ready, get_db_session


@asynccontextmanager
async def api_client() -> AsyncIterator[AsyncClient]:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async def test_session() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    app = create_app()
    app.dependency_overrides[get_db_session] = test_session
    app.dependency_overrides[database_is_ready] = lambda: True
    async with LifespanManager(app):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            yield client
    await engine.dispose()


@pytest.mark.asyncio
async def test_create_and_list_resource_snapshot() -> None:
    payload = {
        "namespace": "default",
        "kind": "Pod",
        "name": "example-pod",
        "status": "Running",
        "payload": {"readyContainers": 1},
    }

    async with api_client() as client:
        created = await client.post("/api/v1/resource-snapshots", json=payload)
        listed = await client.get("/api/v1/resource-snapshots")

    assert created.status_code == 201
    assert created.json()["id"] == 1
    assert created.json()["status"] == "Running"
    assert listed.status_code == 200
    assert listed.json()[0]["payload"] == {"readyContainers": 1}
