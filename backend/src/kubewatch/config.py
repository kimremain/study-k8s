import os
from functools import lru_cache
from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

CONFIG_ROOT = Path(__file__).resolve().parents[2] / "config"
SUPPORTED_ENVIRONMENTS = frozenset({"loc", "dev", "stg", "prd"})


class Settings(BaseSettings):
  app_name: str = "KubeWatch API"
  host: str = "0.0.0.0"
  port: int = 8000
  log_level: str = "info"

  database_host: str = "127.0.0.1"
  database_port: int = 5432
  database_name: str = "kubewatch"
  database_user: str = "kubewatch"
  database_password: SecretStr | None = None
  database_pool_size: int = 5
  database_connect_timeout_seconds: float = 3.0

  # SecretStr prevents accidental plaintext exposure in logs and repr output.
  # The value is optional so the application can run without a Secret.
  api_key: SecretStr | None = None

  # KUBEWATCH_APP_NAME maps to app_name, and so on.
  model_config = SettingsConfigDict(
    env_prefix="KUBEWATCH_",
    case_sensitive=False,
    extra="ignore",
  )


def get_environment_files(environment: str | None = None) -> tuple[Path, ...]:
  selected_environment = environment or os.getenv("KUBEWATCH_ENV")
  if not selected_environment:
    return ()

  if selected_environment not in SUPPORTED_ENVIRONMENTS:
    supported = ", ".join(sorted(SUPPORTED_ENVIRONMENTS))
    raise ValueError(
      f"Unsupported KUBEWATCH_ENV: {selected_environment}. Expected one of: {supported}"
    )

  return (
    CONFIG_ROOT / "base" / "common.env",
    CONFIG_ROOT / "overlays" / selected_environment / f"{selected_environment}.env",
  )


@lru_cache
def get_settings() -> Settings:
  environment_files = get_environment_files()
  if not environment_files:
    return Settings()

  return Settings(_env_file=environment_files)
