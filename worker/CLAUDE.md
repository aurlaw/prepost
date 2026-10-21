# Pre Post — Worker

Pre Post is a personal, single-user iOS app for building Instagram carousel posts outside Instagram and publishing them through the Instagram API. This directory is the Cloudflare Worker behind it, served only at `prepost-api.aurlaw.dev`. The Worker is the only component that holds secrets. Its responsibilities are:

- **Media:** accept uploads, store them in R2 under random keys, return public URLs, and delete on request.
- **Captions:** call Claude with a draft's images and context, and return caption options.
- **Publish:** run the Instagram carousel flow end to end, then clean up R2.
- **Token:** keep the Instagram long-lived token alive.

The sibling `ios/` directory holds the app.

## Manual vs. automated split

Michael does these by hand. Claude Code must **not** do them:

- No git commands (commit, push, branch, etc.).
- No deploys (`wrangler deploy`), no `wrangler secret put`.
- No resource provisioning: no `wrangler kv namespace create`, no R2 bucket or lifecycle changes.
- No `project.pbxproj` edits (iOS side).

Claude Code may write files and config, run `npm install`, and run `npm test`, `npm run typecheck`, `npm run types` and `npm run dev`. There is deliberately no `deploy` script.

## Public-repo hygiene rules

- Never commit secrets or account identifiers (tokens, API keys, `.p8`, Apple Team ID, APNs Key ID, Instagram user ID, Cloudflare account ID).
- Never commit personal content: real photos, captions, Instagram handles, media IDs, permalinks, Page IDs — not in tests, fixtures, previews, sample data, or prompts.
- Tests and previews use generated placeholder images and lorem-style text.
- Credential-shaped test strings are built at runtime (split concatenation), never literals.
- New config values: non-secret → `wrangler.jsonc` `vars` / `Base.xcconfig`; secret or personal → `wrangler secret` / `Local.xcconfig` (gitignored) with a placeholder in the `.example` file.

## Conventions

- TypeScript, `strict` mode.
- **Routing (decided in W1):** a hand-rolled router in `src/router.ts`, with no framework. Routes are `{ method, pattern, handler, public? }`. A pattern contains literal segments and one-segment params (`/media/:key`); there are no regex routes or wildcards. Register routes in `src/index.ts`.
- Module split: `router.ts` (matching, auth gate, 404/405/500), `auth.ts` (bearer check), `http.ts` (`json()`, `error()`, the `ErrorCode` union), `jpeg.ts` (pure JPEG parsing, no I/O), and `routes/*` (handlers).
- Run `npm test` and `npm run typecheck` before declaring a task done.
- Lean dependencies: use native `fetch`, and add no SDK unless a brief says so.
- After changing `wrangler.jsonc`, run `npm run types` and commit the regenerated `worker-configuration.d.ts`.
- Tests use `@cloudflare/vitest-plugin`, the successor to `@cloudflare/vitest-pool-workers`, which is deprecated. Tests run inside the Workers runtime and call the Worker via `exports.default.fetch()` from `cloudflare:workers`.
- `wrangler.jsonc` keeps `workers_dev: false` and `preview_urls: false`. The custom domain is the only entry point.
- Never add `account_id` to `wrangler.jsonc`.
- Local secrets go in `.dev.vars` (gitignored). `.dev.vars.example` lists names only.
- Tests get `APP_TOKEN` from `miniflare.bindings` in `vitest.config.ts` (a fake value built from parts), not from `.dev.vars`. Tests use local Miniflare R2/KV only, never remote resources. JPEG test inputs come from `test/fixtures/jpeg.ts` and are built at runtime; never commit image files.

## API

All routes require `Authorization: Bearer <APP_TOKEN>` except `GET /health`.

- **Auth runs before route matching.** An unauthenticated request to an unknown path gets `401`, not `404`.
- The token comparison is constant-time: SHA-256 both values, then `crypto.subtle.timingSafeEqual`.
- An unset or empty `APP_TOKEN` gives `500 misconfigured`. The check fails closed.

| Method | Path | Success | Notes |
|---|---|---|---|
| `GET` | `/health` | `200 {"status":"ok"}` | Public. |
| `POST` | `/media` | `201 {key, url, width, height, bytes}` | Body: raw JPEG with `Content-Type: image/jpeg`, ≤ 8 MiB. Displayed width (EXIF orientation applied) must be ≤ 1440, and the displayed aspect ratio between 0.8 and 1.91. The bytes are stored exactly as received, at `<uuid>.jpg`. |
| `DELETE` | `/media/:key` | `204` | `key` must be a lowercase `<uuid>.jpg`. Idempotent. |

**Errors:** every error body is `{"error":"<snake_case_code>", ...extra}`. The codes are the `ErrorCode` union in `src/http.ts`, and they are a stable contract with the app: add codes, never rename them. The current codes are:

- Routing and auth: `not_found` 404, `method_not_allowed` 405 (with an `Allow` header), `unauthorized` 401 (with `WWW-Authenticate: Bearer`), `misconfigured` 500, `internal_error` 500.
- `POST /media` validation, in check order: `unsupported_media_type` 415, `too_large` 413, `empty_body` 400, `not_jpeg` 415, `unreadable_jpeg` 422, `too_wide` 422, `aspect_ratio` 422.
- `DELETE /media/:key`: `invalid_key` 400.

An unhandled handler exception is logged and returns `internal_error`. The message and stack are never sent to the client.

**Logging:** one JSON line per request, `{method, path, status, ms}`. `path` is the matched route pattern, such as `/media/:key`, not the key itself. Never log headers, tokens or bodies. The API sends no CORS headers, since only the native app calls it.
