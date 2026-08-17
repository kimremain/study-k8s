import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { App } from "./App";

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe("App", () => {
  it("shows the loading state", () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(() => new Promise<Response>(() => undefined)),
    );

    render(<App />);

    expect(screen.getByText("연결 확인 중...")).toBeInTheDocument();
  });

  it("shows backend information when connected", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          status: "ok",
          service: "KubeWatch API",
          version: "0.1.0",
        }),
      } as Response),
    );

    render(<App />);

    expect(await screen.findByText("Connected")).toBeInTheDocument();
    expect(screen.getByText("KubeWatch API")).toBeInTheDocument();
    expect(screen.getByText("0.1.0")).toBeInTheDocument();
  });

  it("shows an error when the backend request fails", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 503,
      } as Response),
    );

    render(<App />);

    const errorMessage = await screen.findByText(/연결 실패:/);

    expect(errorMessage).toHaveTextContent("HTTP 503");
  });
});
