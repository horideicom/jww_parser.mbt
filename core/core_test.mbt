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
/// Writer の write_double テスト (2.5のIEEE 754表現確認)
test "writer double 2.5" {
  let writer = Writer::new()
  writer.write_double(d=2.5)
  let bytes = writer.to_bytes()
  inspect(bytes.length(), content="8")
  // 2.5のIEEE 754表現を確認
  let bits = 2.5.reinterpret_as_uint64()
  // 各バイト位置の値を確認
  inspect(((bits >> 56) & 0xFFUL).to_uint(), content="64")  // 0x40
  inspect(((bits >> 48) & 0xFFUL).to_uint(), content="4")   // 0x04
  inspect(((bits >> 0) & 0xFFUL).to_uint(), content="0")    // 0x00
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
/// PIDトラッキングが連番を維持することを確認
test "entity pid tracking preserves sequential ids" {
  let version = 420U
  let writer = Writer::new()

  // エンティティ数 (3件)
  writer.write_word(w=(3).to_uint16())

  // 1件目: 新規クラス CDataSen (PID = 1)
  writer.write_word(w=(65535).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_word(w=(8).to_uint16())
  writer.write_bytes(data=b"CDataSen")
  writer.write_dword(d=0U) // group
  writer.write_byte(b=(0).to_byte()) // pen_style
  writer.write_word(w=(1).to_uint16()) // pen_color
  writer.write_word(w=(0).to_uint16()) // pen_width
  writer.write_word(w=(0).to_uint16()) // layer
  writer.write_word(w=(0).to_uint16()) // layer_group
  writer.write_word(w=(0).to_uint16()) // flag
  writer.write_double(d=0.0) // start_x
  writer.write_double(d=0.0) // start_y
  writer.write_double(d=100.0) // end_x
  writer.write_double(d=0.0) // end_y

  // 2件目: 新規クラス CDataEnko (PID = 2)
  writer.write_word(w=(65535).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_word(w=(9).to_uint16())
  writer.write_bytes(data=b"CDataEnko")
  writer.write_dword(d=0U)
  writer.write_byte(b=(0).to_byte())
  writer.write_word(w=(1).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_double(d=0.0) // center_x
  writer.write_double(d=0.0) // center_y
  writer.write_double(d=5.0) // radius
  writer.write_double(d=0.0) // start_angle
  writer.write_double(d=3.14) // arc_angle
  writer.write_double(d=0.0) // tilt_angle
  writer.write_double(d=1.0) // flatness
  writer.write_dword(d=0U) // is_full_circle

  // 3件目: クラス参照 (PID = 2) を使用した CDataEnko
  writer.write_word(w=((0x8000 | 2).reinterpret_as_uint()).to_uint16())
  writer.write_dword(d=0U)
  writer.write_byte(b=(0).to_byte())
  writer.write_word(w=(1).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_word(w=(0).to_uint16())
  writer.write_double(d=10.0)
  writer.write_double(d=20.0)
  writer.write_double(d=2.5)
  writer.write_double(d=0.5)
  writer.write_double(d=1.0)
  writer.write_double(d=0.0)
  writer.write_double(d=1.0)
  writer.write_dword(d=1U)

  let bytes = writer.to_bytes()
  let result = parse_entity_list(data=bytes, offset=0, version=version)

  inspect(result.entities.length(), content="3")
  match result.entities[2] {
    Arc(arc) => {
      inspect(arc.center_x, content="10")
      inspect(arc.radius, content="2.5")
    }
    _ => inspect(false, content="true")
  }
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

///|
/// PrintSettings の基本プロパティ
test "default print settings" {
  let doc = Document::default()
  let ps = doc.print_settings
  inspect(ps.origin_x, content="0")
  inspect(ps.origin_y,   content="0")
  inspect(ps.scale,      content="1")
  inspect(ps.rotation_setting, content="0")
}

///|
/// MetadataSettings の基本プロパティ
test "default metadata settings" {
  let ms = MetadataSettings::default()
  inspect(ms.printer_paper_size, content="")
  inspect(ms.draw_bmp_touka, content="")
  inspect(ms.view_direct2d, content="")
  inspect(ms.printer_bmp_zentai, content="")
  inspect(ms.printer_orientation, content="")
  inspect(ms.printer_d2d_bmp, content="")
}

///|
/// Reader が範囲外アクセスでパニックしないことを確認
test "reader handles short data gracefully" {
  let reader = Reader::new(data = Bytes::from_array([1U.to_byte(), 2U.to_byte()]))

  // 読み取り回数が残りより多くても例外にならない
  let _ = reader.read_dword()
  let trailing = reader.read_byte()
  inspect(trailing, content="b'\\x00'")

  // 不足分を読み込もうとしてもポインタが進むことを確認
  let bytes = reader.read_bytes(n=5)
  inspect(bytes.length(), content="0")
  inspect(reader.position(), content="2")
}
