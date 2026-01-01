///|
/// Coreライブラリの Property-Based Testing

///|
/// Writer の write_dword テスト
test "writer dword roundtrip" {
  let writer = Writer::new()
  let test_val = 42U
  writer.write_dword(d=test_val)
  let bytes = writer.to_bytes()
  inspect(bytes.length(), content="4")
  let b0 = bytes[0].to_uint()
  let b1 = bytes[1].to_uint()
  let b2 = bytes[2].to_uint()
  let b3 = bytes[3].to_uint()
  let reconstructed = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  inspect(reconstructed, content="42")
}

///|
/// シリアライズされたデータが正しいシグネチャで始まる
test "serialize signature" {
  let doc = Document::default()
  let bytes = serialize(doc~)
  inspect(bytes.length() >= 8, content="true")
  inspect(bytes[0], content="b'\\x4A'")
  inspect(bytes[1], content="b'\\x77'")
  inspect(bytes[2], content="b'\\x77'")
  inspect(bytes[3], content="b'\\x44'")
  inspect(bytes[4], content="b'\\x61'")
  inspect(bytes[5], content="b'\\x74'")
  inspect(bytes[6], content="b'\\x61'")
  inspect(bytes[7], content="b'\\x2E'")
}

///|
/// Document::default の基本プロパティ
test "default document" {
  let doc = Document::default()
  inspect(doc.layer_groups.length(), content="16")
  inspect(doc.entities.length(), content="0")
  inspect(doc.block_defs.length(), content="0")
}

///|
/// Layer::default の基本プロパティ
test "default layer" {
  let l = Layer::default()
  inspect(l.state, content="2")
  inspect(l.protect, content="0")
  inspect(l.name, content="")
}

///|
/// Entity::type_name の IMAGE 対応確認
/// 注: Image構造体は内部関数でのみ生成されるため、間接的にテスト
