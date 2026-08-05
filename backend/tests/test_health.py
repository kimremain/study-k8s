from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import pytest
from asgi_lifespan import LifespanManager
from httpx import ASGITransport, AsyncClient

from kubewatch.api.app import create_app


@asynccontextmanager
async def api_client() -> AsyncIterator[AsyncClient]:
    app = create_app()
    async with LifespanManager(app):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            yield client


@pytest.mark.asyncio
async def test_healthz_reports_process_health() -> None:
    async with api_client() as client:
        response = await client.get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_readyz_reports_ready_during_lifespan() -> None:
    async with api_client() as client:
        response = await client.get("/readyz")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


@pytest.mark.asyncio
async def test_openapi_exposes_health_routes() -> None:
    async with api_client() as client:
        schema = (await client.get("/openapi.json")).json()

    assert "/healthz" in schema["paths"]
    assert "/readyz" in schema["paths"]
