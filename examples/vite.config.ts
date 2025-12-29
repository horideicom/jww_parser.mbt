import { defineConfig } from "vite";
import path from "path";

export default defineConfig({
  base: "/jww_parser.mbt/",
  build: {
    outDir: "dist",
    sourcemap: true,
  },
  resolve: {
    alias: {
      "@wasm": path.resolve(__dirname, "../target/wasm-gc/release/build"),
    },
  },
  optimizeDeps: {
    exclude: ["@f12o/three-dxf"],
  },
  server: {
    port: 5173,
  },
});
