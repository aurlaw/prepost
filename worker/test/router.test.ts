import { env } from "cloudflare:workers";
import { createExecutionContext } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import { json } from "../src/http";
import { createRouter } from "../src/router";
import { authHeaders, BASE, callDirect } from "./helpers";

const ctx = createExecutionContext();

describe("router", () => {
  afterEach(() => vi.restoreAllMocks());

  it("uses the test token from vitest.config.ts, not .dev.vars", () => {
    expect(env.APP_TOKEN).toBe("test-" + "app-token");
  });

  it("passes one-segment params to the handler", async () => {
    const route = createRouter([
      { method: "GET", pattern: "/things/:id", handler: async (_r, _e, _c, params) => json(params) },
    ]);
    const { response, pattern } = await route(new Request(`${BASE}/things/a%20b`, { headers: authHeaders() }), env, ctx);
    expect(await response.json()).toEqual({ id: "a b" });
    expect(pattern).toBe("/things/:id");
  });

  it("does not match extra or missing segments", async () => {
    const route = createRouter([{ method: "GET", pattern: "/things/:id", handler: async () => json({}) }]);
    for (const path of ["/things", "/things/a/b"]) {
      const { response } = await route(new Request(`${BASE}${path}`, { headers: authHeaders() }), env, ctx);
      expect(response.status).toBe(404);
    }
  });

  it("lists every allowed method on 405", async () => {
    const route = createRouter([
      { method: "GET", pattern: "/x", handler: async () => json({}) },
      { method: "PUT", pattern: "/x", handler: async () => json({}) },
    ]);
    const { response } = await route(new Request(`${BASE}/x`, { method: "DELETE", headers: authHeaders() }), env, ctx);
    expect(response.status).toBe(405);
    expect(response.headers.get("Allow")).toBe("GET, PUT");
  });

  it("returns 500 internal_error without leaking the message", async () => {
    const logged = vi.spyOn(console, "error").mockImplementation(() => {});
    const route = createRouter([
      {
        method: "GET",
        pattern: "/boom",
        handler: async () => {
          throw new Error("secret detail");
        },
      },
    ]);
    const { response } = await route(new Request(`${BASE}/boom`, { headers: authHeaders() }), env, ctx);
    expect(response.status).toBe(500);
    const text = await response.text();
    expect(JSON.parse(text)).toEqual({ error: "internal_error" });
    expect(text).not.toContain("secret detail");
    expect(logged).toHaveBeenCalledOnce();
  });
});

describe("request logging", () => {
  afterEach(() => vi.restoreAllMocks());

  it("logs method, route pattern, status and ms — never the key, token or body", async () => {
    const lines: string[] = [];
    vi.spyOn(console, "log").mockImplementation((line: string) => lines.push(line));
    const key = "0f8fad5b-d9cb-469f-a165-70867728950e.jpg";
    await callDirect(new Request(`${BASE}/media/${key}`, { method: "DELETE", headers: authHeaders() }));

    expect(lines).toHaveLength(1);
    const entry = JSON.parse(lines[0]!);
    expect(Object.keys(entry).sort()).toEqual(["method", "ms", "path", "status"]);
    expect(entry).toMatchObject({ method: "DELETE", path: "/media/:key", status: 204 });
    expect(lines[0]).not.toContain(key);
    expect(lines[0]).not.toContain(env.APP_TOKEN);
  });
});
