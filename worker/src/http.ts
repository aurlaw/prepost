/** Stable error codes. The app switches on these, so never rename one. */
export type ErrorCode =
  | "not_found"
  | "method_not_allowed"
  | "internal_error"
  | "unauthorized"
  | "misconfigured"
  | "unsupported_media_type"
  | "too_large"
  | "empty_body"
  | "not_jpeg"
  | "unreadable_jpeg"
  | "too_wide"
  | "aspect_ratio"
  | "invalid_key";

export function json(body: unknown, status = 200, headers?: HeadersInit): Response {
  return Response.json(body, { status, headers });
}

export function error(
  status: number,
  code: ErrorCode,
  extra: Record<string, unknown> = {},
  headers?: HeadersInit,
): Response {
  return json({ error: code, ...extra }, status, headers);
}
