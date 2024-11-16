import type { Config } from "tailwindcss";

export default {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "var(--background)",
        foreground: "var(--foreground)",
      },
    },
    fontFamily: {
      "geist-sans": "var(--font-geist-sans)",
      "geist-mono": "var(--font-geist-mono)",
      spaceMono: ["'Space Mono'", "monospace"],
      doto: ["'Doto'", "sans-serif"],
    },
  },
  plugins: [],
} satisfies Config;
