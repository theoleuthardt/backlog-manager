import path from "node:path";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, loadEnv, type Plugin } from "vite";
import { parseApiUrl } from "./src/lib/apiUrl.ts";
import { THEME_CACHE_KEY } from "./src/lib/themes.ts";

const src = path.resolve(import.meta.dirname, "src");
const envDir = path.resolve(import.meta.dirname, "..");

const themeBootScript = (): Plugin => ({
  name: "theme-boot-script",
  transformIndexHtml: (html) =>
    html.replace(
      "<!--theme-boot-script-->",
      `<script>try{var t=JSON.parse(localStorage.getItem(${JSON.stringify(THEME_CACHE_KEY)}));if(t&&t.variables){var r=document.documentElement;for(var k in t.variables){r.style.setProperty(k,t.variables[k])}r.dataset.theme=t.dataTheme;r.style.colorScheme=t.colorScheme}}catch(e){}</script>`,
    ),
});

const validateApiUrl = (mode: string): Plugin => ({
  name: "validate-api-url",
  apply: "build",
  config() {
    if (mode !== "production") return;
    const env = loadEnv(mode, envDir, "NEXT_PUBLIC_");
    const result = parseApiUrl(env.NEXT_PUBLIC_API_URL, true);
    if (!result.success) {
      throw new Error(`Invalid NEXT_PUBLIC_API_URL: ${result.message}`);
    }
  },
});

export default defineConfig(({ mode }) => ({
  plugins: [react(), tailwindcss(), themeBootScript(), validateApiUrl(mode)],
  envDir,
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
}));
