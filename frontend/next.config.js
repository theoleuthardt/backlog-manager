/**
 * The app now lives in frontend/, but .env files stay at the repo root
 * (compose.yml needs them there for its own variable substitution). Load
 * them explicitly before env.js validates process.env - Next's own env
 * loading only checks its own cwd.
 */
import { config as loadEnv } from "dotenv";
loadEnv({ path: new URL("../.env", import.meta.url) });

/**
 * Run `build` or `dev` with `SKIP_ENV_VALIDATION` to skip env validation. This is especially useful
 * for Docker builds.
 *
 * Dynamic import (not a static one) so it runs after loadEnv() above: ES
 * module imports are hoisted ahead of a file's own top-level statements
 * regardless of source order, so a static import here would validate
 * process.env before loadEnv() ever ran.
 */
await import("./src/env.js");

/** @type {import("next").NextConfig} */
const config = {
  output: "standalone",
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

  images: {
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
