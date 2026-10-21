import { error, json } from "../http";
import { parseJpeg } from "../jpeg";
import type { Handler } from "../router";

/** Instagram's limits (verified 2026-10-20). The app resizes; we only reject. */
export const MAX_BYTES = 8 * 1024 * 1024;
export const MAX_WIDTH = 1440;
export const MIN_RATIO = 0.8;
export const MAX_RATIO = 1.91;
const RATIO_EPSILON = 1e-3;

const KEY_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$/;

/** Reads the body, stopping as soon as it exceeds `max` bytes. */
async function readBody(request: Request, max: number): Promise<Uint8Array | "too_large"> {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      await reader.cancel();
      return "too_large";
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let at = 0;
  for (const c of chunks) {
    out.set(c, at);
    at += c.byteLength;
  }
  return out;
}

export function mediaUrl(baseUrl: string, key: string): string {
  return `${baseUrl.replace(/\/+$/, "")}/${key}`;
}

export const uploadMedia: Handler = async (request, env) => {
  const contentType = request.headers.get("Content-Type")?.split(";")[0]?.trim().toLowerCase();
  if (contentType !== "image/jpeg") return error(415, "unsupported_media_type");

  const declared = request.headers.get("Content-Length");
  if (declared !== null && /^\d+$/.test(declared) && Number(declared) > MAX_BYTES) {
    return error(413, "too_large", { maxBytes: MAX_BYTES });
  }

  const bytes = await readBody(request, MAX_BYTES);
  if (bytes === "too_large") return error(413, "too_large", { maxBytes: MAX_BYTES });
  if (bytes.length === 0) return error(400, "empty_body");
  if (bytes.length < 3 || bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) {
    return error(415, "not_jpeg");
  }

  const info = parseJpeg(bytes);
  if (!info) return error(422, "unreadable_jpeg");
  const { width, height } = info;

  if (width > MAX_WIDTH) return error(422, "too_wide", { width, maxWidth: MAX_WIDTH });

  const ratio = width / height;
  if (ratio < MIN_RATIO - RATIO_EPSILON || ratio > MAX_RATIO + RATIO_EPSILON) {
    return error(422, "aspect_ratio", {
      width,
      height,
      ratio: Math.round(ratio * 10000) / 10000,
      min: MIN_RATIO,
      max: MAX_RATIO,
    });
  }

  const key = `${crypto.randomUUID()}.jpg`;
  await env.MEDIA.put(key, bytes, {
    httpMetadata: { contentType: "image/jpeg", cacheControl: "public, max-age=31536000, immutable" },
    customMetadata: { width: String(width), height: String(height) },
  });

  return json({ key, url: mediaUrl(env.MEDIA_BASE_URL, key), width, height, bytes: bytes.length }, 201);
};

export const deleteMedia: Handler = async (_request, env, _ctx, params) => {
  const key = params.key ?? "";
  if (!KEY_PATTERN.test(key)) return error(400, "invalid_key");
  await env.MEDIA.delete(key);
  return new Response(null, { status: 204 });
};
