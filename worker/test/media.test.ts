import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import { MAX_BYTES } from "../src/routes/media";
import { makeJpeg } from "./fixtures/jpeg";
import { authHeaders, BASE, call, callDirect } from "./helpers";

const KEY_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$/;

function upload(body: BodyInit | null, headers: Record<string, string> = { "Content-Type": "image/jpeg" }) {
  return call("/media", { method: "POST", headers: authHeaders(headers), body });
}

async function expectError(res: Response, status: number, body: Record<string, unknown>) {
  expect(res.status).toBe(status);
  expect(await res.json()).toEqual(body);
}

describe("POST /media validation", () => {
  it("rejects a non-JPEG content type with 415", async () => {
    await expectError(await upload(makeJpeg({ width: 100, height: 100 }), { "Content-Type": "image/png" }), 415, {
      error: "unsupported_media_type",
    });
  });

  it("rejects a missing content type with 415", async () => {
    await expectError(await upload(makeJpeg({ width: 100, height: 100 }), {}), 415, { error: "unsupported_media_type" });
  });

  it("accepts content-type parameters", async () => {
    const res = await upload(makeJpeg({ width: 100, height: 100 }), { "Content-Type": "Image/JPEG; charset=binary" });
    expect(res.status).toBe(201);
  });

  it("rejects an oversized Content-Length with 413 without reading the body", async () => {
    let pulled = false;
    // highWaterMark 0: pull() only runs when someone actually reads.
    const body = new ReadableStream(
      {
        pull(controller) {
          pulled = true;
          controller.close();
        },
      },
      { highWaterMark: 0 },
    );
    const req = new Request(`${BASE}/media`, {
      method: "POST",
      headers: authHeaders({ "Content-Type": "image/jpeg", "Content-Length": String(MAX_BYTES + 1) }),
      body,
    });
    const res = await callDirect(req);
    await expectError(res, 413, { error: "too_large", maxBytes: MAX_BYTES });
    expect(pulled).toBe(false);
    expect(req.bodyUsed).toBe(false);
  });

  it("rejects an oversized body with no Content-Length with 413", async () => {
    const chunk = new Uint8Array(1024 * 1024);
    chunk.set([0xff, 0xd8, 0xff]);
    let sent = 0;
    const body = new ReadableStream<Uint8Array>({
      pull(controller) {
        if (sent > MAX_BYTES) return controller.close();
        controller.enqueue(chunk.slice());
        sent += chunk.length;
      },
    });
    const req = new Request(`${BASE}/media`, {
      method: "POST",
      headers: authHeaders({ "Content-Type": "image/jpeg" }),
      body,
    });
    const res = await callDirect(req);
    await expectError(res, 413, { error: "too_large", maxBytes: MAX_BYTES });
  });

  it("accepts a body exactly at the limit as far as the size check goes", async () => {
    const big = new Uint8Array(MAX_BYTES);
    big.set(makeJpeg({ width: 100, height: 100 }));
    const res = await upload(big);
    expect(res.status).toBe(201);
  });

  it("rejects an empty body with 400", async () => {
    await expectError(await upload(new Uint8Array()), 400, { error: "empty_body" });
    await expectError(await upload(null), 400, { error: "empty_body" });
  });

  it("rejects non-JPEG bytes with 415 not_jpeg", async () => {
    await expectError(await upload(new TextEncoder().encode("\x89PNG\r\n\x1a\n....")), 415, { error: "not_jpeg" });
  });

  it("rejects a JPEG with no SOF with 422 unreadable_jpeg", async () => {
    await expectError(await upload(makeJpeg({ width: 1, height: 1, omitSof: true })), 422, { error: "unreadable_jpeg" });
  });

  it("accepts width 1440", async () => {
    expect((await upload(makeJpeg({ width: 1440, height: 1440 }))).status).toBe(201);
  });

  it("rejects width 1441 with 422 too_wide", async () => {
    await expectError(await upload(makeJpeg({ width: 1441, height: 1441 })), 422, {
      error: "too_wide",
      width: 1441,
      maxWidth: 1440,
    });
  });

  it.each([
    ["1:1", 1080, 1080],
    ["exact 4:5", 1440, 1800],
    ["exact 1.91:1", 1146, 600],
  ])("accepts %s", async (_label, width, height) => {
    const res = await upload(makeJpeg({ width, height }));
    expect(res.status).toBe(201);
    expect(await res.json()).toMatchObject({ width, height });
  });

  it("rejects 9:16 with 422 aspect_ratio", async () => {
    await expectError(await upload(makeJpeg({ width: 1080, height: 1920 })), 422, {
      error: "aspect_ratio",
      width: 1080,
      height: 1920,
      ratio: 0.5625,
      min: 0.8,
      max: 1.91,
    });
  });

  it("rejects wider than 1.91:1 with 422 aspect_ratio", async () => {
    const res = await upload(makeJpeg({ width: 1440, height: 700 }));
    expect(res.status).toBe(422);
    expect(await res.json()).toMatchObject({ error: "aspect_ratio" });
  });

  it("judges a rotated image on its displayed size", async () => {
    // Stored 1800×1440 landscape; orientation 6 displays as 1440×1800 portrait (4:5).
    const rotated = makeJpeg({ width: 1800, height: 1440, orientation: 6 });
    const res = await upload(rotated);
    expect(res.status).toBe(201);
    expect(await res.json()).toMatchObject({ width: 1440, height: 1800 });

    // Without the rotation the same stored size would be too wide.
    const unrotated = makeJpeg({ width: 1800, height: 1440 });
    expect((await upload(unrotated)).status).toBe(422);
  });

  it("rejects a rotated image whose displayed ratio is out of range", async () => {
    // Stored 1920×1080 landscape (16:9, OK as-is) displays as 1080×1920 (9:16).
    const res = await upload(makeJpeg({ width: 1920, height: 1080, orientation: 6 }));
    expect(res.status).toBe(422);
    expect(await res.json()).toMatchObject({ error: "aspect_ratio", width: 1080, height: 1920 });
  });
});

describe("POST /media success", () => {
  it("stores the exact bytes in R2 and returns key, url and displayed size", async () => {
    const bytes = makeJpeg({ width: 1080, height: 1350, orientation: 1, fillers: 2 });
    const res = await upload(bytes);
    expect(res.status).toBe(201);
    const body = (await res.json()) as { key: string; url: string; width: number; height: number; bytes: number };
    expect(body.key).toMatch(KEY_RE);
    expect(body.url).toBe(`${env.MEDIA_BASE_URL}/${body.key}`);
    expect(body).toMatchObject({ width: 1080, height: 1350, bytes: bytes.length });

    const obj = await env.MEDIA.get(body.key);
    expect(obj).not.toBeNull();
    expect(new Uint8Array(await obj!.arrayBuffer())).toEqual(bytes);
    expect(obj!.httpMetadata?.contentType).toBe("image/jpeg");
    expect(obj!.httpMetadata?.cacheControl).toBe("public, max-age=31536000, immutable");
    expect(obj!.customMetadata).toEqual({ width: "1080", height: "1350" });
  });

  it("does not duplicate a trailing slash in the URL", async () => {
    const res = await callDirect(
      new Request(`${BASE}/media`, {
        method: "POST",
        headers: authHeaders({ "Content-Type": "image/jpeg" }),
        body: makeJpeg({ width: 100, height: 100 }),
      }),
      { MEDIA_BASE_URL: "https://media.example.com/" as Env["MEDIA_BASE_URL"] },
    );
    const { key, url } = (await res.json()) as { key: string; url: string };
    expect(url).toBe(`https://media.example.com/${key}`);
  });
});

describe("DELETE /media/:key", () => {
  it("deletes an object and is idempotent", async () => {
    const res = await upload(makeJpeg({ width: 100, height: 100 }));
    const { key } = (await res.json()) as { key: string };
    expect(await env.MEDIA.head(key)).not.toBeNull();

    const first = await call(`/media/${key}`, { method: "DELETE", headers: authHeaders() });
    expect(first.status).toBe(204);
    expect(await first.text()).toBe("");
    expect(await env.MEDIA.head(key)).toBeNull();

    const second = await call(`/media/${key}`, { method: "DELETE", headers: authHeaders() });
    expect(second.status).toBe(204);
  });

  it.each([
    ["uppercase", "0F8FAD5B-D9CB-469F-A165-70867728950E.jpg"],
    ["non-.jpg", "0f8fad5b-d9cb-469f-a165-70867728950e.png"],
    ["no extension", "0f8fad5b-d9cb-469f-a165-70867728950e"],
    ["path traversal (encoded)", "..%2F0f8fad5b-d9cb-469f-a165-70867728950e.jpg"],
    ["arbitrary name", "secrets.jpg"],
  ])("rejects a %s key with 400", async (_label, key) => {
    await expectError(await call(`/media/${key}`, { method: "DELETE", headers: authHeaders() }), 400, {
      error: "invalid_key",
    });
  });

  it("does not route a multi-segment traversal path", async () => {
    const res = await call("/media/../media/x.jpg", { method: "DELETE", headers: authHeaders() });
    // URL normalisation collapses this to /media/x.jpg, which is an invalid key.
    expect(res.status).toBe(400);
  });
});
