#!/usr/bin/env node
///|
/// ビルド後のJSファイルにパッチを当てるスクリプト
/// read_double 関数を DataView.getFloat64 を使用するように修正

const fs = require('fs');
const path = require('path');

const jsFile = path.join(__dirname, '../target/js/release/build/jww_parser.js');

console.log('Patching', jsFile);

let content = fs.readFileSync(jsFile, 'utf-8');

// read_double 関数を探して置換
const oldPattern = /function f4ah6o\$jww_parser\$core\$\$Reader\$read_double\(self\) \{[\s\S]*?\n\}/;
const newFunction = `function f4ah6o$jww_parser$core$$Reader$read_double(self) {
  // DataView.getFloat64 を使用して IEEE 754 double を読み取る
  const buffer = new ArrayBuffer(8);
  const view = new DataView(buffer);
  for (let i = 0; i < 8; i++) {
    view.setUint8(i, self.data[self.pos++]);
  }
  return view.getFloat64(0, true); // true = little endian
}`;

if (oldPattern.test(content)) {
  content = content.replace(oldPattern, newFunction);
  fs.writeFileSync(jsFile, content, 'utf-8');
  console.log('Successfully patched read_double function');
} else {
  console.log('Could not find read_double function to patch (already patched?)');
}
