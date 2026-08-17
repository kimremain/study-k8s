import { useEffect, useState } from "react";

type ApiStatus = {
  status: "ok";
  service: string;
  version: string;
};

type ConnectionState =
  | { type: "loading" }
  | { type: "connected"; data: ApiStatus }
  | { type: "error"; message: string };

export function App() {
  const [connection, setConnection] = useState<ConnectionState>({
    type: "loading",
  });

  useEffect(() => {
    const controller = new AbortController();

    async function loadStatus() {
      try {
        const response = await fetch("/api/v1/status", {
          signal: controller.signal,
        });
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }

        const data = (await response.json()) as ApiStatus;
        setConnection({ type: "connected", data });
      } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
          return;
        }

        setConnection({
          type: "error",
          message: error instanceof Error ? error.message : "Unknown error",
        });
      }
    }

    void loadStatus();

    return () => controller.abort();
  }, []);

  return (
    <main>
      <p className="eyebrow">Kubernetes study project</p>
      <h1>KubeWatch</h1>
      <p>웹사이트 상태와 응답 시간을 관찰하는 대시보드를 준비하고 있습니다.</p>
      <section className="status-card" aria-live="polite">
        <h2>Backend connection</h2>

        {connection.type === "loading" && <p>연결 확인 중...</p>}

        {connection.type === "connected" && (
          <>
            <p className="status-ok">Connected</p>
            <dl>
              <div>
                <dt>Service</dt>
                <dd>{connection.data.service}</dd>
              </div>
              <div>
                <dt>Version</dt>
                <dd>{connection.data.version}</dd>
              </div>
            </dl>
          </>
        )}

        {connection.type === "error" && (
          <p className="status-error">
            연결 실패: {connection.message}
          </p>
        )}
      </section>
    </main>
  );
}
