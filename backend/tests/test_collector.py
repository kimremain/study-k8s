from datetime import UTC, datetime

import httpx
import pytest

from kubewatch.collector.kubernetes import KubernetesApiClient
from kubewatch.collector.snapshots import build_resource_snapshots


@pytest.mark.asyncio
async def test_kubernetes_api_client_lists_pods_and_deployments() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        documents = {
            "/api/v1/namespaces/kubewatch-dev/pods": {
                "kind": "PodList",
                "items": [{"metadata": {"name": "api-1"}}],
            },
            "/apis/apps/v1/namespaces/kubewatch-dev/deployments": {
                "kind": "DeploymentList",
                "items": [{"metadata": {"name": "api"}}],
            },
        }
        return httpx.Response(200, json=documents[request.url.path])

    http_client = httpx.AsyncClient(
        base_url="https://kubernetes.default.svc",
        transport=httpx.MockTransport(handler),
    )
    client = KubernetesApiClient(http_client)

    async with client:
        pods, deployments = await client.list_workloads("kubewatch-dev")

    assert pods[0]["metadata"]["name"] == "api-1"
    assert deployments[0]["metadata"]["name"] == "api"


@pytest.mark.asyncio
async def test_kubernetes_api_client_rejects_invalid_list() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        kind = "Pod" if request.url.path.endswith("/pods") else "DeploymentList"
        return httpx.Response(200, json={"kind": kind, "items": []})

    http_client = httpx.AsyncClient(
        base_url="https://kubernetes.default.svc",
        transport=httpx.MockTransport(handler),
    )
    client = KubernetesApiClient(http_client)

    async with client:
        with pytest.raises(ValueError, match="invalid PodList"):
            await client.list_workloads("kubewatch-dev")


def test_build_resource_snapshots_extracts_bounded_workload_status() -> None:
    observed_at = datetime(2026, 8, 21, 1, 0, tzinfo=UTC)
    pods = [
        {
            "metadata": {"name": "api-abc", "uid": "pod-uid"},
            "spec": {"nodeName": "gke-node-1"},
            "status": {
                "phase": "Running",
                "podIP": "10.0.0.10",
                "containerStatuses": [
                    {"ready": True, "restartCount": 1},
                    {"ready": False, "restartCount": 2},
                ],
            },
        }
    ]
    deployments = [
        {
            "metadata": {"name": "api", "uid": "deployment-uid", "generation": 3},
            "spec": {"replicas": 2},
            "status": {
                "observedGeneration": 3,
                "updatedReplicas": 2,
                "readyReplicas": 2,
                "availableReplicas": 2,
                "conditions": [{"type": "Available", "status": "True"}],
            },
        }
    ]

    snapshots = build_resource_snapshots(
        "kubewatch-dev", pods, deployments, observed_at=observed_at
    )

    assert [(row.kind, row.name, row.status) for row in snapshots] == [
        ("Pod", "api-abc", "Running"),
        ("Deployment", "api", "Available"),
    ]
    assert snapshots[0].observed_at == observed_at
    assert snapshots[0].payload["readyContainers"] == 1
    assert snapshots[0].payload["restartCount"] == 3
    assert snapshots[1].payload["readyReplicas"] == 2
    assert "spec" not in snapshots[0].payload


def test_build_resource_snapshots_rejects_resource_without_name() -> None:
    with pytest.raises(ValueError, match="metadata.name"):
        build_resource_snapshots("kubewatch-dev", [{"metadata": {}}], [])
