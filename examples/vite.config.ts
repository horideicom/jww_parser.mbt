import { defineConfig } from "vite";
import path from "path";

export default defineConfig({
  base: "/jww_parser.mbt/",
  build: {
    outDir: "dist",
    sourcemap: true,
  },
  optimizeDeps: {
    include: ["three"],
    exclude: ["@f12o/three-dxf"],
  },
  resolve: {
    alias: {
      // Use local jww-parser-mbt in development
      "jww-parser-mbt": path.resolve(__dirname, "../dist/index.mjs"),
    },
  },
  server: {
    port: 5173,
  },
});
