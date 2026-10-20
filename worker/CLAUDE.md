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

- TypeScript, `strict` mode. No framework in P0; the routing approach is decided in W1.
- Run `npm test` and `npm run typecheck` before declaring a task done.
- Lean dependencies: use native `fetch`, and add no SDK unless a brief says so.
- After changing `wrangler.jsonc`, run `npm run types` and commit the regenerated `worker-configuration.d.ts`.
- Tests use `@cloudflare/vitest-plugin`, the successor to `@cloudflare/vitest-pool-workers`, which is deprecated. Tests run inside the Workers runtime and call the Worker via `exports.default.fetch()` from `cloudflare:workers`.
- `wrangler.jsonc` keeps `workers_dev: false` and `preview_urls: false`. The custom domain is the only entry point.
- Never add `account_id` to `wrangler.jsonc`.
- Local secrets go in `.dev.vars` (gitignored). `.dev.vars.example` lists names only.
