#!/usr/bin/env node
///|
/// ビルド後のJSファイルにパッチを当てるスクリプト
/// read_double 関数を DataView.getFloat64 を使用するように修正

const fs = require('fs');
const path = require('path');

const jsFile = path.join(__dirname, '../target/js/release/build/jww_parser.js');

console.log('Patching', jsFile);

let content = fs.readFileSync(jsFile, 'utf-8');

// read_double 関数定義を探して置換（$ の数はビルドごとに変わる可能性があるため寛容にマッチ）
const oldPattern = /function f4ah6o\$jww_parser\$core\$+\$?Reader\$read_double\(self\) \{[\s\S]*?\n\}/;
const newFunction = `function f4ah6o$jww_parser$core$Reader$read_double(self) {
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
  console.log('Patched function definition');
} else {
  console.log('Could not find read_double function definition (already patched?)');
}

// すべての関数呼び出し箇所も置換（$ の数のバリエーションに対応）
const oldCallPattern = /f4ah6o\$jww_parser\$core\$+\$?Reader\$read_double/g;
const newCallName = `f4ah6o$jww_parser$core$Reader$read_double`;

const beforeCallCount = (content.match(oldCallPattern) || []).length;
content = content.replace(oldCallPattern, newCallName);
const afterCallCount = (content.match(newCallName) || []).length;

console.log(`Updated ${beforeCallCount} function call references`);

fs.writeFileSync(jsFile, content, 'utf-8');
console.log('Successfully patched read_double function');
