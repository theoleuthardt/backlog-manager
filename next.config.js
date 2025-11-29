/**
 * Run `build` or `dev` with `SKIP_ENV_VALIDATION` to skip env validation. This is especially useful
 * for Docker builds.
 */
import "./src/env.js";

/** @type {import("next").NextConfig} */
const config = {
  output: "standalone",
  allowedDevOrigins: [
    "local-origin.dev",
    "*.local-origin.dev",
    "10.20.146.74",
    "10.20.*",
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
