import asyncio
import logging

from kubewatch.collector.kubernetes import KubernetesApiClient
from kubewatch.collector.snapshots import build_resource_snapshots
from kubewatch.config import get_settings
from kubewatch.db.session import close_database, get_session_factory

logger = logging.getLogger(__name__)


async def collect() -> int:
    settings = get_settings()
    async with KubernetesApiClient.from_service_account(
        settings.kubernetes_api_timeout_seconds
    ) as kubernetes:
        pods, deployments = await kubernetes.list_workloads(settings.collector_namespace)

    snapshots = build_resource_snapshots(settings.collector_namespace, pods, deployments)
    async with get_session_factory()() as session:
        session.add_all(snapshots)
        await session.commit()

    logger.info(
        "Stored %d resource snapshots (pods=%d, deployments=%d, namespace=%s)",
        len(snapshots),
        len(pods),
        len(deployments),
        settings.collector_namespace,
    )
    return len(snapshots)


async def run() -> None:
    try:
        await collect()
    finally:
        await close_database()


def main() -> None:
    settings = get_settings()
    logging.basicConfig(level=settings.log_level.upper())
    asyncio.run(run())


if __name__ == "__main__":
    main()
