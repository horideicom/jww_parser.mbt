// FFI implementation for file I/O in tests
export function js_readFileSync(path, _encoding) {
  const fs = require('fs');
  const buffer = fs.readFileSync(path);
  // Convert Buffer to MoonBit Bytes (array of integers 0-255)
  return Array.from(buffer);
}
