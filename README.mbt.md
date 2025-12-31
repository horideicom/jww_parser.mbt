# f4ah6o/jww_parser

[![npm version](https://badge.fury.io/js/jww-parser.svg)](https://www.npmjs.com/package/jww-parser)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

JW-CADファイル（*.jww）をパースし、DXF形式に変換するライブラリです。MoonBitで実装されており、WebAssembly対応によりブラウザ環境でも高速に動作します。

## 特徴

* **クロスプラットフォーム**: ブラウザとNode.jsの両方で動作
* **型安全**: MoonBitの静的型チェックによる堅牢な実装
* **高速パース**: WebAssembly対応のバイナリパーサー
* **SJIS対応**: 日本語環境でのJWWファイルを正しく処理
* **モジュラー設計**: コアパーサーとDXFコンバーターを分離

## インストール

```bash
pnpm add jww-parser
# または
npm install jww-parser
```

## 使い方

### 基本的な使用方法

```typescript
import { jww_to_dxf, parse, to_dxf_string } from 'jww-parser';

// JWWファイルを読み込んで直接DXFに変換
const jwwData = await readFile('drawing.jww');
const dxfString = jww_to_dxf(jwwData);

// パースしてから変換（途中結果を操作したい場合）
const doc = parse(jwwData);
const dxfString = to_dxf_string(doc);
```

### Node.js でのファイル変換例

```typescript
import { readFileSync, writeFileSync } from 'node:fs';
import { jww_to_dxf } from 'jww-parser';

const jwwData = readFileSync('input.jww');
const dxfString = jww_to_dxf(jwwData);
writeFileSync('output.dxf', dxfString);
```

### ブラウザでの使用例

```typescript
import { jww_to_dxf } from 'jww-parser';

// File API でJWWファイルを読み込み
const file = fileInput.files[0];
const arrayBuffer = await file.arrayBuffer();
const jwwData = new Uint8Array(arrayBuffer);

// DXFに変換
const dxfString = jww_to_dxf(jwwData);

// ファイルとしてダウンロード
const blob = new Blob([dxfString], { type: 'application/dxf' });
const url = URL.createObjectURL(blob);
const a = document.createElement('a');
a.href = url;
a.download = 'output.dxf';
a.click();
```

## サポートしているエンティティ

| エンティティ | 説明 | JW-CAD クラス |
|------------|------|--------------|
| Line | 直線 | CDataSen |
| Arc / Circle | 円弧 / 円 | CDataEnko |
| Point | 点 | CDataTen |
| Text | 文字 | CDataMoji |
| Solid | 塗りつぶし | CDataSolid |
| Block | ブロック挿入 | CDataBlock |

## API

### パース関数

```typescript
// JWWバイナリデータをパースしてDocumentを返す
function parse(data: Uint8Array): Document

// JWWバイナリデータを直接DXF文字列に変換
function jww_to_dxf(data: Uint8Array): string
```

### 変換関数

```typescript
// DocumentをDXF文字列に変換
function to_dxf_string(doc: Document): string

// DocumentをDXF Documentオブジェクトに変換
function to_dxf_document(doc: Document): DxfDocument

// DocumentをJSON文字列に変換
function to_json_string(doc: Document): string
```

### 型定義

```typescript
interface Document {
  header: Header;
  layers: Layer[];
  entities: Entity[];
  blocks: Block[];
}

interface Entity {
  type: 'line' | 'arc' | 'circle' | 'point' | 'text' | 'solid' | 'block';
  layer: number;
  color: number;
  // ... エンティティ固有のプロパティ
}
```

## デモアプリケーション

`examples/` ディレクトリに、ブラウザでJWWファイルをDXFに変換してプレビューできるデモアプリが含まれています。

```bash
cd examples
pnpm install
pnpm run dev
```

デモでは以下の機能を体験できます：

* JWWファイルのドラッグ&ドロップアップロード
* WASM-GC での高速変換
* Three.js によるDXFの3Dプレビュー（パン/ズーム対応）
* 変換結果のリアルタイム確認とダウンロード

## 開発

```bash
# リポジトリのクローン
git clone https://github.com/f4ah6o/jww_parser.mbt.git
cd jww_parser.mbt

# 依存関係のインストール
pnpm install

# ビルド
pnpm run build

# テスト
moon test

# デモアプリの実行
cd examples && pnpm install && pnpm run dev
```

## ライセンス

AGPL-3.0

## 関連プロジェクト

* [f4ah6o/dxf-parser](https://github.com/f4ah6o/dxf-parser) - DXFパーサー
* [f4ah6o/three-dxf](https://github.com/f4ah6o/three-dxf) - Three.jsでDXFを表示
