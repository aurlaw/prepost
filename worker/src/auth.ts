import { error } from "./http";

const encoder = new TextEncoder();

async function sha256(value: string): Promise<ArrayBuffer> {
  return crypto.subtle.digest("SHA-256", encoder.encode(value));
}

/**
 * Returns null when the request carries the correct bearer token, otherwise the
 * error response to send. Fails closed when `APP_TOKEN` is not configured.
 */
export async function checkAuth(request: Request, env: Env): Promise<Response | null> {
  const expected = env.APP_TOKEN;
  if (typeof expected !== "string" || expected === "") {
    console.error(JSON.stringify({ level: "error", error: "APP_TOKEN is not configured" }));
    return error(500, "misconfigured");
  }

  const unauthorized = () => error(401, "unauthorized", {}, { "WWW-Authenticate": "Bearer" });

  const header = request.headers.get("Authorization");
  if (!header) return unauthorized();
  const match = /^Bearer[ \t]+(\S+)[ \t]*$/i.exec(header);
  if (!match) return unauthorized();

  // Hashing gives equal-length inputs, which timingSafeEqual requires.
  const [given, wanted] = await Promise.all([sha256(match[1]!), sha256(expected)]);
  return crypto.subtle.timingSafeEqual(given, wanted) ? null : unauthorized();
}
