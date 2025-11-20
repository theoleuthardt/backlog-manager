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

    unoptimized: false,

    localPatterns: [
      {
        pathname: "/**",
      },
    ],
  },
};

export default config;
