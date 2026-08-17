from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
  app_name: str = "KubeWatch API"
  host: str = "0.0.0.0"
  port: int = 8000
  log_level: str = "info"

  # SecretStr prevents accidental plaintext exposure in logs and repr output.
  # The value is optional so the application can run without a Secret.
  api_key: SecretStr | None = None

  # KUBEWATCH_APP_NAME maps to app_name, and so on.
  model_config = SettingsConfigDict(
    env_prefix="KUBEWATCH_",
    case_sensitive=False,
    extra="ignore",
  )
@lru_cache
def get_settings() -> Settings:
  return Settings()
