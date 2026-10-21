import { createRouter } from "./router";
import { health } from "./routes/health";
import { deleteMedia, uploadMedia } from "./routes/media";

const route = createRouter([
  { method: "GET", pattern: "/health", handler: health, public: true },
  { method: "POST", pattern: "/media", handler: uploadMedia },
  { method: "DELETE", pattern: "/media/:key", handler: deleteMedia },
]);

export default {
  async fetch(request, env, ctx): Promise<Response> {
    const started = Date.now();
    const { response, pattern } = await route(request, env, ctx);
    // Never log headers, tokens or bodies. Matched routes log their pattern
    // (not e.g. the media key); unmatched requests log the raw path.
    console.log(
      JSON.stringify({
        method: request.method,
        path: pattern ?? new URL(request.url).pathname,
        status: response.status,
        ms: Date.now() - started,
      }),
    );
    return response;
  },
} satisfies ExportedHandler<Env>;
