from typing import Literal

from fastapi import APIRouter, Request, Response, status
from pydantic import BaseModel

router = APIRouter(tags=["health"])


class HealthResponse(BaseModel):
    status: Literal["ok", "ready", "not_ready"]


@router.get("/healthz", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get("/readyz", response_model=HealthResponse)
async def readiness(request: Request, response: Response) -> HealthResponse:
    if not getattr(request.app.state, "ready", False):
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return HealthResponse(status="not_ready")
    return HealthResponse(status="ready")
