import { exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

describe("routing", () => {
  it("GET /health returns 200 with status ok", async () => {
    const res = await exports.default.fetch("https://example.com/health");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: "ok" });
  });

  it("unknown path returns 404", async () => {
    const res = await exports.default.fetch("https://example.com/nope");
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: "not_found" });
  });
});
