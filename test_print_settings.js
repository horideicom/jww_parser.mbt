// Test script to verify print settings parsing
const path = require('path');
const fs = require('fs');

// Load the compiled jww_parser module
const modulePath = path.join(__dirname, 'target/js/release/build/jww_parser.js');

// Read the JWW file
const jwwFilePath = path.join(__dirname, '../jwwfile/木造平面例.jww');
const buffer = fs.readFileSync(jwwFilePath);
const data = Array.from(buffer);

// Import and parse
const { parse } = require(modulePath);
const result = parse(data);

// Print the results
console.log('=== 印刷設定のパース結果 ===');
console.log('Origin X:', result.print_settings.origin_x);
console.log('Origin Y:', result.print_settings.origin_y);
console.log('Scale:', result.print_settings.scale);
console.log('Rotation Setting:', result.print_settings.rotation_setting);

const hasNonZero =
  result.print_settings.origin_x !== 0 ||
  result.print_settings.origin_y !== 0 ||
  result.print_settings.scale !== 1 ||
  result.print_settings.rotation_setting !== 0;

console.log('Has non-zero value:', hasNonZero);

process.exit(hasNonZero ? 0 : 1);
