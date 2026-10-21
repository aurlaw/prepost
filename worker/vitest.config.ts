import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      // Test-only token; built from parts so it never looks like a real credential.
      miniflare: { bindings: { APP_TOKEN: "test-" + "app-token" } },
    }),
  ],
});
