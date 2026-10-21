import { createExecutionContext } from "cloudflare:test";
import { env, exports } from "cloudflare:workers";
import worker from "../src/index";

export const BASE = "https://example.com";

export function authHeaders(extra: Record<string, string> = {}): Record<string, string> {
  return { Authorization: `Bearer ${env.APP_TOKEN}`, ...extra };
}

/** Calls the Worker through the runtime, as a client would. */
export function call(path: string, init?: RequestInit): Promise<Response> {
  return exports.default.fetch(`${BASE}${path}`, init);
}

/** Calls the Worker's fetch handler directly, optionally with an env override. */
export function callDirect(request: Request, envOverride: Partial<Env> = {}): Promise<Response> {
  return worker.fetch(
    request as Request<unknown, IncomingRequestCfProperties>,
    { ...env, ...envOverride } as Env,
    createExecutionContext(),
  );
}
