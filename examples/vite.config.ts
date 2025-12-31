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
  server: {
    port: 5173,
  },
});
