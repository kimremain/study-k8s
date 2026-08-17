from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

from kubewatch import __version__
from kubewatch.config import get_settings

router = APIRouter(prefix="/api/v1", tags=["status"])


class ApiStatusResponse(BaseModel):
    status: Literal["ok"]
    service: str
    version: str


@router.get("/status", response_model=ApiStatusResponse)
async def api_status() -> ApiStatusResponse:
    settings = get_settings()
    return ApiStatusResponse(
        status="ok",
        service=settings.app_name,
        version=__version__,
    )
