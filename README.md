# Pre Post

A personal iOS app for building Instagram carousel posts outside Instagram. Drafts are assembled on the phone — photos added and reordered, a caption typed or generated with Claude — and then published directly through the Instagram API. A small Cloudflare Worker sits between the app and the outside services: it stores images, calls Claude for caption options, runs the publish flow, and keeps the Instagram token fresh. It is a single-user project and is not distributed.

## Components

| Path | What it is |
|---|---|
| [`worker/`](worker/) | Cloudflare Worker (TypeScript) serving the API at `prepost-api.aurlaw.dev`. Uses R2 for media (public read at `prepost-media.aurlaw.dev`) and KV for state. |
| [`ios/`](ios/) | SwiftUI iOS app (iOS 26+). Drafts are stored locally; images live in R2 and are referenced by URL. |

## Setup

See [`worker/`](worker/) and [`ios/`](ios/) for component-specific setup.

Secrets and personal configuration are **not** in this repository. They are configured outside it:

- **Worker:** secrets are set with `wrangler secret put`; local development values go in `worker/.dev.vars` (gitignored), using `worker/.dev.vars.example` as a template.
- **iOS:** signing team and local overrides go in `ios/Configs/Local.xcconfig` (gitignored), using `ios/Configs/Local.xcconfig.example` as a template. The API bearer token is entered in the app and stored in the Keychain.

## License

See [LICENSE](LICENSE).
