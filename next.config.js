/**
 * Run `build` or `dev` with `SKIP_ENV_VALIDATION` to skip env validation. This is especially useful
 * for Docker builds.
 */
import "./src/env.js";

// Check if this is a Tauri build (embedded Node.js server)
const isTauriBuild = process.env.TAURI_BUILD === "true";

/** @type {import("next").NextConfig} */
const config = {
  // Use standalone output for both web and Tauri (embeds Node.js server)
  output: "standalone",

  // Allow connections from Tauri webview
  allowedDevOrigins: [
    "local-origin.dev",
    "*.local-origin.dev",
    "10.20.146.74",
    "10.20.*",
    "tauri://localhost",
    "http://localhost",
  ],

  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "avatars.githubusercontent.com",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "cdn.discordapp.com",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "howlongtobeat.com",
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
