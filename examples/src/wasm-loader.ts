// MoonBit WASM-GC loader
// This module loads and interfaces with the MoonBit WASM-GC module

export interface JwwParserWasm {
  jww_to_dxf(data: Uint8Array): string;
  parse(data: Uint8Array): unknown;
  to_dxf_string(doc: unknown): string;
}

const WASM_PATH = new URL(
  "../target/wasm-gc/release/build/jww_parser.wasm",
  import.meta.url
);

let wasmInstance: WebAssembly.Instance | null = null;
let wasmModule: WebAssembly.Module | null = null;

export async function loadWasm(): Promise<JwwParserWasm> {
  if (wasmInstance) {
    return wasmInstance.exports as JwwParserWasm;
  }

  try {
    // Fetch and compile the WASM module
    const response = await fetch(WASM_PATH);
    if (!response.ok) {
      throw new Error(`Failed to fetch WASM: ${response.statusText}`);
    }

    const buffer = await response.arrayBuffer();
    wasmModule = await WebAssembly.compile(buffer);

    // Create import object for MoonBit WASM-GC
    const imports = createMoonBitImports();

    // Instantiate the module
    wasmInstance = await WebAssembly.instantiate(wasmModule, imports);

    return wasmInstance.exports as JwwParserWasm;
  } catch (error) {
    console.error("Failed to load WASM:", error);
    throw error;
  }
}

function createMoonBitImports(): WebAssembly.Imports {
  return {
    // MoonBit runtime imports
    moonbit: {
      // Add any required runtime functions here
      // This will depend on the actual MoonBit WASM-GC exports
    },
    env: {
      // JavaScript environment functions
      memory: new WebAssembly.Memory({ initial: 256, maximum: 32768 }),
    },
  };
}

export function isWasmSupported(): boolean {
  return typeof WebAssembly === "object" && typeof WebAssembly.instantiate === "function";
}

export async function getWasmVersion(): Promise<string> {
  try {
    const wasm = await loadWasm();
    // Version function if exported
    if (typeof (wasm as any).get_version === "function") {
      return (wasm as any).get_version();
    }
    return "unknown";
  } catch {
    return "error";
  }
}
