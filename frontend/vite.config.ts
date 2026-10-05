import path from "node:path";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, type Plugin } from "vite";
import { THEME_CACHE_KEY } from "./src/lib/themes";

const src = path.resolve(import.meta.dirname, "src");

/**
 * Inlines the script that re-applies the theme ThemeProvider cached in
 * localStorage before first paint, so a reload never flashes the default
 * theme. It lives in the HTML (not in the bundle) because it has to run
 * before any module loads.
 */
const themeBootScript = (): Plugin => ({
  name: "theme-boot-script",
  transformIndexHtml: (html) =>
    html.replace(
      "<!--theme-boot-script-->",
      `<script>try{var t=JSON.parse(localStorage.getItem(${JSON.stringify(THEME_CACHE_KEY)}));if(t&&t.variables){var r=document.documentElement;for(var k in t.variables){r.style.setProperty(k,t.variables[k])}r.dataset.theme=t.dataTheme;r.style.colorScheme=t.colorScheme}}catch(e){}</script>`,
    ),
});

/**
 * The app lives in frontend/ but the .env files stay at the repo root
 * (compose.yml needs them there), hence `envDir`. `NEXT_PUBLIC_` stays an
 * exposed prefix next to `VITE_` so the existing NEXT_PUBLIC_API_URL
 * variable (repo variable, .env files, compose build args) keeps working.
 * One build serves the web image and the Tauri desktop app.
 */
export default defineConfig({
  plugins: [react(), tailwindcss(), themeBootScript()],
  envDir: path.resolve(import.meta.dirname, ".."),
  envPrefix: ["VITE_", "NEXT_PUBLIC_"],
  resolve: {
    alias: [
      { find: /^~\//, replacement: `${src}/` },
      {
        find: /^components\//,
        replacement: `${path.join(src, "app/_components")}/`,
      },
      {
        find: /^shadcn_components\//,
        replacement: `${path.join(src, "components")}/`,
      },
    ],
  },
  server: {
    port: 3000,
    strictPort: true,
  },
  build: {
    outDir: "dist",
    sourcemap: false,
    target: "es2022",
    cssCodeSplit: true,
    reportCompressedSize: false,
    chunkSizeWarningLimit: 600,
    rolldownOptions: {
      output: {
        codeSplitting: {
          groups: [
            {
              name: "react",
              test: /node_modules[\\/](react|react-dom|scheduler|react-router)[\\/]/,
              priority: 30,
            },
            {
              name: "radix",
              test: /node_modules[\\/]@radix-ui[\\/]/,
              priority: 20,
            },
            {
              name: "motion",
              test: /node_modules[\\/](motion|motion-dom|motion-utils|framer-motion)[\\/]/,
              priority: 20,
            },
            {
              name: "query",
              test: /node_modules[\\/]@tanstack[\\/]/,
              priority: 20,
            },
          ],
        },
      },
    },
  },
});
