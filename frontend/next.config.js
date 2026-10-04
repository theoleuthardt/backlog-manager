/**
 * Next.js config.
 *
 * - Unsupported Node versions abort here with a clear message instead of
 *   failing later with cryptic webpack errors.
 * - The app lives in frontend/ but .env files stay at the repo root
 *   (compose.yml needs them there), so they are loaded explicitly before
 *   env.js validates process.env; Next's own env loading only checks its own
 *   cwd. env.js is imported dynamically because static imports are hoisted
 *   above top-level statements and would validate before loadEnv() ran. Set
 *   SKIP_ENV_VALIDATION to skip the validation (useful for Docker builds).
 * - TAURI_BUILD=1 switches to a static export: the desktop app is a WebView
 *   loading static files, no Next.js server runs inside it (docs/TAURI.md).
 *   Branching on an env var instead of swapping in a separate config file
 *   means a build killed mid-run can never leave the wrong config on disk.
 */
const SUPPORTED_NODE_MAJORS = [22];
const nodeMajor = Number(process.versions.node.split(".")[0]);
if (!SUPPORTED_NODE_MAJORS.includes(nodeMajor)) {
  throw new Error(
    `Node.js ${process.versions.node} is not supported: this project runs on Node ${SUPPORTED_NODE_MAJORS.join(" or ")} (Node 20 is end of life, and versions like 23.x break the build with cryptic webpack errors). Run \`nvm use\` in the repo root.`,
  );
}

import { config as loadEnv } from "dotenv";
loadEnv({ path: new URL("../.env", import.meta.url), quiet: true });

await import("./src/env.js");

const isTauriBuild = process.env.TAURI_BUILD === "1";

/** @type {import("next").NextConfig} */
const config = {
  output: isTauriBuild ? "export" : "standalone",
  allowedDevOrigins: [
    "local-origin.dev",
    "*.local-origin.dev",
    "10.20.146.74",
    "10.20.*",
  ],

  typescript: {
    ignoreBuildErrors: false,
  },

  turbopack: {},

  images: isTauriBuild
    ? { unoptimized: true }
    : {
        remotePatterns: [
          {
            protocol: "https",
            hostname: "howlongtobeat.com",
            pathname: "/**",
          },
          {
            protocol: "https",
            hostname: "images.igdb.com",
            pathname: "/**",
          },
        ],
        domains: [],
        unoptimized: false,
        localPatterns: [
          {
            pathname: "/**",
          },
        ],
      },
};

export default config;
