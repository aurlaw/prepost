import { checkAuth } from "./auth";
import { error } from "./http";

export type Params = Record<string, string>;

export type Handler = (
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  params: Params,
) => Promise<Response>;

export interface Route {
  method: string;
  /** Literal segments and one-segment params, e.g. `/media/:key`. */
  pattern: string;
  handler: Handler;
  /** Skips auth. Only `GET /health` should set this. */
  public?: boolean;
}

export interface RouteResult {
  response: Response;
  /** The matched route pattern, or undefined if nothing matched. Safe to log. */
  pattern?: string;
}

function splitPath(path: string): string[] {
  return path.split("/").filter((s) => s !== "");
}

function matchPattern(pattern: string[], path: string[]): Params | null {
  if (pattern.length !== path.length) return null;
  const params: Params = {};
  for (let i = 0; i < pattern.length; i++) {
    const p = pattern[i]!;
    const s = path[i]!;
    if (p.startsWith(":")) {
      let value: string;
      try {
        value = decodeURIComponent(s);
      } catch {
        return null;
      }
      params[p.slice(1)] = value;
    } else if (p !== s) {
      return null;
    }
  }
  return params;
}

export function createRouter(routes: Route[]) {
  const compiled = routes.map((r) => ({ ...r, segments: splitPath(r.pattern) }));

  return async function route(request: Request, env: Env, ctx: ExecutionContext): Promise<RouteResult> {
    const path = splitPath(new URL(request.url).pathname);
    const matches = compiled
      .map((r) => ({ route: r, params: matchPattern(r.segments, path) }))
      .filter((m): m is { route: (typeof compiled)[number]; params: Params } => m.params !== null);

    const exact = matches.find((m) => m.route.method === request.method);

    // Public routes are matched first and skip auth. Everything else is
    // authenticated before we reveal whether the path exists.
    if (!exact?.route.public) {
      const denied = await checkAuth(request, env);
      if (denied) return { response: denied, pattern: exact?.route.pattern };
    }

    if (!exact) {
      if (matches.length === 0) return { response: error(404, "not_found") };
      const allow = [...new Set(matches.map((m) => m.route.method))].join(", ");
      return {
        response: error(405, "method_not_allowed", {}, { Allow: allow }),
        pattern: matches[0]!.route.pattern,
      };
    }

    try {
      return { response: await exact.route.handler(request, env, ctx, exact.params), pattern: exact.route.pattern };
    } catch (err) {
      console.error(
        JSON.stringify({
          level: "error",
          pattern: exact.route.pattern,
          error: err instanceof Error ? `${err.name}: ${err.message}` : String(err),
        }),
      );
      return { response: error(500, "internal_error"), pattern: exact.route.pattern };
    }
  };
}
