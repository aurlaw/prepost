import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import { authHeaders, BASE, call, callDirect } from "./helpers";

async function expectUnauthorized(res: Response) {
  expect(res.status).toBe(401);
  expect(res.headers.get("WWW-Authenticate")).toBe("Bearer");
  expect(await res.json()).toEqual({ error: "unauthorized" });
}

describe("auth", () => {
  it("rejects a missing header", async () => {
    await expectUnauthorized(await call("/media/x", { method: "DELETE" }));
  });

  it("rejects the wrong scheme", async () => {
    await expectUnauthorized(
      await call("/media/x", { method: "DELETE", headers: { Authorization: `Basic ${env.APP_TOKEN}` } }),
    );
  });

  it("rejects a wrong token", async () => {
    await expectUnauthorized(
      await call("/media/x", { method: "DELETE", headers: { Authorization: "Bearer " + "not-" + "the-token" } }),
    );
  });

  it("rejects an empty bearer value", async () => {
    await expectUnauthorized(await call("/media/x", { method: "DELETE", headers: { Authorization: "Bearer " } }));
  });

  it("lets the correct token through", async () => {
    const res = await call("/media/x", { method: "DELETE", headers: authHeaders() });
    expect(res.status).toBe(400); // reached the handler: invalid key
  });

  it("accepts a lowercase scheme", async () => {
    const res = await call("/media/x", { method: "DELETE", headers: { Authorization: `bearer ${env.APP_TOKEN}` } });
    expect(res.status).toBe(400);
  });

  it("returns 401, not 404, for an unknown path without a token", async () => {
    await expectUnauthorized(await call("/nope"));
  });

  it("returns 404 for an unknown path with a token", async () => {
    const res = await call("/nope", { headers: authHeaders() });
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: "not_found" });
  });

  it("returns 405 with Allow for a wrong method on /media", async () => {
    const res = await call("/media", { method: "GET", headers: authHeaders() });
    expect(res.status).toBe(405);
    expect(res.headers.get("Allow")).toBe("POST");
    expect(await res.json()).toEqual({ error: "method_not_allowed" });
  });

  it("requires a token for non-GET methods on /health", async () => {
    await expectUnauthorized(await call("/health", { method: "POST" }));
  });

  it("fails closed with 500 when APP_TOKEN is empty", async () => {
    const res = await callDirect(
      new Request(`${BASE}/media/x`, { method: "DELETE", headers: { Authorization: "Bearer " } }),
      { APP_TOKEN: "" },
    );
    expect(res.status).toBe(500);
    expect(await res.json()).toEqual({ error: "misconfigured" });
  });

  it("keeps /health public even when APP_TOKEN is empty", async () => {
    const res = await callDirect(new Request(`${BASE}/health`), { APP_TOKEN: "" });
    expect(res.status).toBe(200);
  });
});
