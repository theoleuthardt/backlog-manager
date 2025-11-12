/**
 * Run `build` or `dev` with `SKIP_ENV_VALIDATION` to skip env validation. This is especially useful
 * for Docker builds.
 */
import "./src/env.js";

/** @type {import("next").NextConfig} */
const config = {
  allowedDevOrigins: [
    "local-origin.dev",
    "*.local-origin.dev",
    "10.20.146.74",
    "10.20.*",

  ],
  images: {
    domains: ["avatars.githubusercontent.com", "cdn.discordapp.com"],
  }
};

export default config;
