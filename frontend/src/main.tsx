import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import "./styles.css";

function App() {
  return (
    <main>
      <p className="eyebrow">Kubernetes study project</p>
      <h1>KubeWatch</h1>
      <p>웹사이트 상태와 응답 시간을 관찰하는 대시보드를 준비하고 있습니다.</p>
    </main>
  );
}

const root = document.getElementById("root");

if (!root) {
  throw new Error("root element not found");
}

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
