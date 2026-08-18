from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import pytest
from asgi_lifespan import LifespanManager
from httpx import ASGITransport, AsyncClient

from kubewatch.api.app import create_app
from kubewatch.db.session import database_is_ready


@asynccontextmanager
async def api_client() -> AsyncIterator[AsyncClient]:
    app = create_app()
    app.dependency_overrides[database_is_ready] = lambda: True
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
async def test_readyz_fails_when_database_is_unavailable() -> None:
    app = create_app()
    app.dependency_overrides[database_is_ready] = lambda: False
    async with LifespanManager(app):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/readyz")

    assert response.status_code == 503
    assert response.json() == {"status": "not_ready"}


@pytest.mark.asyncio
async def test_openapi_exposes_health_routes() -> None:
    async with api_client() as client:
        schema = (await client.get("/openapi.json")).json()

    assert "/healthz" in schema["paths"]
    assert "/readyz" in schema["paths"]
    assert "/api/v1/status" in schema["paths"]
    assert "/api/v1/resource-snapshots" in schema["paths"]


@pytest.mark.asyncio
async def test_api_status_reports_service_information() -> None:
  async with api_client() as client:
    response = await client.get("/api/v1/status")

  assert response.status_code == 200
  assert response.json() == {
    "status": "ok",
    "service": "KubeWatch API",
    "version": "0.1.0",
  }
