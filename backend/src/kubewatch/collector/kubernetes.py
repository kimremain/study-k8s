import asyncio
import os
from pathlib import Path
from typing import Any

import httpx

SERVICE_ACCOUNT_ROOT = Path("/var/run/secrets/kubernetes.io/serviceaccount")


class KubernetesApiClient:
    def __init__(self, client: httpx.AsyncClient) -> None:
        self._client = client

    @classmethod
    def from_service_account(cls, timeout_seconds: float) -> "KubernetesApiClient":
        host = os.environ.get("KUBERNETES_SERVICE_HOST")
        port = os.environ.get("KUBERNETES_SERVICE_PORT_HTTPS", "443")
        if not host:
            raise RuntimeError("KUBERNETES_SERVICE_HOST is required")

        token = (SERVICE_ACCOUNT_ROOT / "token").read_text(encoding="utf-8").strip()
        client = httpx.AsyncClient(
            base_url=f"https://{host}:{port}",
            headers={"Authorization": f"Bearer {token}"},
            verify=str(SERVICE_ACCOUNT_ROOT / "ca.crt"),
            timeout=timeout_seconds,
        )
        return cls(client)

    async def __aenter__(self) -> "KubernetesApiClient":
        return self

    async def __aexit__(self, *_: object) -> None:
        await self._client.aclose()

    async def list_workloads(self, namespace: str) -> tuple[list[dict[str, Any]], ...]:
        pod_path = f"/api/v1/namespaces/{namespace}/pods"
        deployment_path = f"/apis/apps/v1/namespaces/{namespace}/deployments"
        pod_response, deployment_response = await asyncio.gather(
            self._client.get(pod_path),
            self._client.get(deployment_path),
        )
        pod_response.raise_for_status()
        deployment_response.raise_for_status()
        return (
            self._items(pod_response.json(), "PodList"),
            self._items(deployment_response.json(), "DeploymentList"),
        )

    @staticmethod
    def _items(document: Any, expected_kind: str) -> list[dict[str, Any]]:
        if not isinstance(document, dict) or document.get("kind") != expected_kind:
            raise ValueError(f"Kubernetes API returned an invalid {expected_kind}")
        items = document.get("items")
        if not isinstance(items, list) or not all(isinstance(item, dict) for item in items):
            raise ValueError(f"Kubernetes API returned invalid items for {expected_kind}")
        return items
