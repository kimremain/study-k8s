from datetime import UTC, datetime
from typing import Any

from kubewatch.db.models import ResourceSnapshot


def build_resource_snapshots(
    namespace: str,
    pods: list[dict[str, Any]],
    deployments: list[dict[str, Any]],
    observed_at: datetime | None = None,
) -> list[ResourceSnapshot]:
    batch_time = observed_at or datetime.now(UTC)
    return [
        *(pod_snapshot(namespace, pod, batch_time) for pod in pods),
        *(deployment_snapshot(namespace, deployment, batch_time) for deployment in deployments),
    ]


def pod_snapshot(
    namespace: str,
    pod: dict[str, Any],
    observed_at: datetime,
) -> ResourceSnapshot:
    metadata = pod.get("metadata", {})
    status = pod.get("status", {})
    container_statuses = status.get("containerStatuses") or []
    return ResourceSnapshot(
        namespace=namespace,
        kind="Pod",
        name=_resource_name(metadata),
        status=status.get("phase") or "Unknown",
        observed_at=observed_at,
        payload={
            "uid": metadata.get("uid"),
            "nodeName": pod.get("spec", {}).get("nodeName"),
            "podIP": status.get("podIP"),
            "readyContainers": sum(
                container.get("ready") is True for container in container_statuses
            ),
            "totalContainers": len(container_statuses),
            "restartCount": sum(
                int(container.get("restartCount", 0)) for container in container_statuses
            ),
            "reason": status.get("reason"),
        },
    )


def deployment_snapshot(
    namespace: str,
    deployment: dict[str, Any],
    observed_at: datetime,
) -> ResourceSnapshot:
    metadata = deployment.get("metadata", {})
    spec = deployment.get("spec", {})
    status = deployment.get("status", {})
    conditions = status.get("conditions") or []
    return ResourceSnapshot(
        namespace=namespace,
        kind="Deployment",
        name=_resource_name(metadata),
        status=_deployment_status(conditions),
        observed_at=observed_at,
        payload={
            "uid": metadata.get("uid"),
            "generation": metadata.get("generation"),
            "observedGeneration": status.get("observedGeneration"),
            "desiredReplicas": spec.get("replicas", 1),
            "updatedReplicas": status.get("updatedReplicas", 0),
            "readyReplicas": status.get("readyReplicas", 0),
            "availableReplicas": status.get("availableReplicas", 0),
            "unavailableReplicas": status.get("unavailableReplicas", 0),
        },
    )


def _resource_name(metadata: Any) -> str:
    if not isinstance(metadata, dict) or not isinstance(metadata.get("name"), str):
        raise ValueError("Kubernetes resource is missing metadata.name")
    return metadata["name"]


def _deployment_status(conditions: Any) -> str:
    if not isinstance(conditions, list):
        return "Unknown"
    current = {
        condition.get("type"): condition.get("status")
        for condition in conditions
        if isinstance(condition, dict)
    }
    if current.get("Available") == "True":
        return "Available"
    if current.get("Progressing") == "True":
        return "Progressing"
    if current.get("ReplicaFailure") == "True":
        return "ReplicaFailure"
    return "Unavailable"
