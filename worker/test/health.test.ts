import { describe, expect, it } from "vitest";
import { call } from "./helpers";

describe("GET /health", () => {
  it("returns 200 with status ok and needs no token", async () => {
    const res = await call("/health");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: "ok" });
  });
});
