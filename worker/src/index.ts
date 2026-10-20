function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

export default {
  async fetch(request): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ status: "ok" });
    }

    return json({ error: "not_found" }, 404);
  },
} satisfies ExportedHandler<Env>;
