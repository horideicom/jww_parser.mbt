///|
/// JWWドキュメントシリアライザー

///|
/// JWWドキュメントをバイト列にシリアライズする
pub fn serialize(doc~ : Document) -> Bytes {
  let writer = Writer::new()

  // シグネチャ
  writer.write_bytes(data=signature())

  // バージョン
  writer.write_dword(d=doc.version)

  // ヘッダー情報
  write_cstring(writer~, s=doc.memo)
  writer.write_dword(d=doc.paper_size)
  writer.write_dword(d=doc.write_layer_group)

  // レイヤグループ（16グループ）
  for lg in doc.layer_groups {
    writer.write_dword(d=lg.state)
    writer.write_dword(d=lg.write_layer)
    writer.write_double(d=lg.scale)
    writer.write_dword(d=lg.protect)
    for l in lg.layers {
      writer.write_dword(d=l.state)
      writer.write_dword(d=l.protect)
    }
  }

  // エンティティリスト
  write_entity_list(writer~, entities=doc.entities, version=doc.version)
  writer.to_bytes()
}

///|
/// MFC CString形式で文字列を書き込む
fn write_cstring(writer~ : Writer, s~ : String) -> Unit {
  // 簡易実装: ASCIIのみ対応
  let bytes = string_to_ascii(s~)
  let len = bytes.length()
  if len < 255 {
    writer.write_byte(b=len.to_byte())
  } else if len < 65535 {
    let b255 : Int = 255
    writer.write_byte(b=b255.to_byte())
    writer.write_word(w=len.to_uint16())
  } else {
    let b255 : Int = 255
    let w65535 : Int = 65535
    writer.write_byte(b=b255.to_byte())
    writer.write_word(w=w65535.to_uint16())
    writer.write_dword(d=len.to_uint())
  }
  if len > 0 {
    writer.write_bytes(data=bytes)
  }
}

///|
/// エンティティリストを書き込む
fn write_entity_list(
  writer~ : Writer,
  entities~ : Array[Entity],
  version~ : UInt,
) -> Unit {
  let count = entities.length()
  writer.write_word(w=count.to_uint16())

  // PID トラッキング
  let mut class_map : Array[String] = Array::new()
  for _ in 0..<256 {
    class_map.push("")
  }
  let mut next_pid : UInt = 1U
  for entity in entities {
    let (class_name, updated_map, updated_pid) = track_class(
      entity~,
      class_map~,
      next_pid~,
    )
    write_entity(writer~, entity~, class_name~, version~)
    class_map = updated_map
    next_pid = updated_pid
  }
}

///|
/// クラス名をトラッキングして PID を管理
fn track_class(
  entity~ : Entity,
  class_map~ : Array[String],
  next_pid~ : UInt,
) -> (String, Array[String], UInt) {
  let class_name = entity_class_name(entity~)

  // 既存の PID を検索
  let mut found_pid : UInt = 0U
  let mut i = 1
  while i <= 255 && i <= class_map.length() - 1 {
    if class_map[i] == class_name {
      found_pid = i.to_uint()
      break
    }
    i = i + 1
  }
  let (updated_map, updated_next_pid) = if found_pid != 0U {
    (class_map, next_pid)
  } else {
    // 新しいクラス定義を書き込む必要がある
    let pid = next_pid
    let new_map = class_map
    if pid < 256U {
      new_map[pid.reinterpret_as_int()] = class_name
    }
    (new_map, pid + 1)
  }
  (class_name, updated_map, updated_next_pid)
}

///|
/// エンティティのクラス名を取得
fn entity_class_name(entity~ : Entity) -> String {
  match entity {
    Line(_) => "CDataSen"
    Arc(_) => "CDataEnko"
    Point(_) => "CDataTen"
    Text(_) => "CDataMoji"
    Solid(_) => "CDataSolid"
    Block(_) => "CDataBlock"
  }
}

///|
/// エンティティを書き込む
fn write_entity(
  writer~ : Writer,
  entity~ : Entity,
  class_name~ : String,
  version~ : UInt,
) -> Unit {
  // クラス ID（簡易実装: 常に新しいクラス定義）
  writer.write_word(w=(65535).to_uint16())
  writer.write_word(w=(0).to_uint16())

  // クラス名
  let name_bytes = string_to_ascii(s=class_name)
  writer.write_word(w=name_bytes.length().to_uint16())
  writer.write_bytes(data=name_bytes)

  // エンティティデータ
  match entity {
    Line(line) => write_line(writer~, line~, version~)
    Arc(arc) => write_arc(writer~, arc~, version~)
    Point(point) => write_point(writer~, point~, version~)
    Text(text) => write_text(writer~, text~, version~)
    Solid(solid) => write_solid(writer~, solid~, version~)
    Block(block) => write_block(writer~, block~, version~)
  }
}

///|
/// 直線を書き込む
fn write_line(writer~ : Writer, line~ : Line, version~ : UInt) -> Unit {
  write_entity_base(writer~, base=line.base, version~)
  writer.write_double(d=line.start_x)
  writer.write_double(d=line.start_y)
  writer.write_double(d=line.end_x)
  writer.write_double(d=line.end_y)
}

///|
/// 円弧/円を書き込む
fn write_arc(writer~ : Writer, arc~ : Arc, version~ : UInt) -> Unit {
  write_entity_base(writer~, base=arc.base, version~)
  writer.write_double(d=arc.center_x)
  writer.write_double(d=arc.center_y)
  writer.write_double(d=arc.radius)
  writer.write_double(d=arc.start_angle)
  writer.write_double(d=arc.arc_angle)
  writer.write_double(d=arc.tilt_angle)
  writer.write_double(d=arc.flatness)
  writer.write_dword(d=if arc.is_full_circle { 1U } else { 0U })
}

///|
/// 点を書き込む
fn write_point(writer~ : Writer, point~ : Point, version~ : UInt) -> Unit {
  write_entity_base(writer~, base=point.base, version~)
  writer.write_double(d=point.x)
  writer.write_double(d=point.y)
  writer.write_dword(d=if point.is_temporary { 1U } else { 0U })
  if point.base.pen_style == 100 {
    writer.write_dword(d=point.code)
    writer.write_double(d=point.angle)
    writer.write_double(d=point.scale)
  }
}

///|
/// 文字を書き込む
fn write_text(writer~ : Writer, text~ : Text, version~ : UInt) -> Unit {
  write_entity_base(writer~, base=text.base, version~)
  writer.write_double(d=text.start_x)
  writer.write_double(d=text.start_y)
  writer.write_double(d=text.end_x)
  writer.write_double(d=text.end_y)
  writer.write_dword(d=text.text_type)
  writer.write_double(d=text.size_x)
  writer.write_double(d=text.size_y)
  writer.write_double(d=text.spacing)
  writer.write_double(d=text.angle)
  write_cstring(writer~, s=text.font_name)
  write_cstring(writer~, s=text.content)
}

///|
/// 塗りつぶしを書き込む
fn write_solid(writer~ : Writer, solid~ : Solid, version~ : UInt) -> Unit {
  write_entity_base(writer~, base=solid.base, version~)
  writer.write_double(d=solid.point1_x)
  writer.write_double(d=solid.point1_y)
  writer.write_double(d=solid.point4_x)
  writer.write_double(d=solid.point4_y)
  writer.write_double(d=solid.point2_x)
  writer.write_double(d=solid.point2_y)
  writer.write_double(d=solid.point3_x)
  writer.write_double(d=solid.point3_y)
  if solid.base.pen_color == 10 {
    writer.write_dword(d=solid.color)
  }
}

///|
/// ブロックを書き込む
fn write_block(writer~ : Writer, block~ : Block, version~ : UInt) -> Unit {
  write_entity_base(writer~, base=block.base, version~)
  writer.write_double(d=block.ref_x)
  writer.write_double(d=block.ref_y)
  writer.write_double(d=block.scale_x)
  writer.write_double(d=block.scale_y)
  writer.write_double(d=block.rotation)
  writer.write_dword(d=block.def_number)
}

///|
/// エンティティ基本属性を書き込む
fn write_entity_base(
  writer~ : Writer,
  base~ : EntityBase,
  version~ : UInt,
) -> Unit {
  writer.write_dword(d=base.group)
  writer.write_byte(b=base.pen_style)
  writer.write_word(w=base.pen_color)
  if version >= 351 {
    writer.write_word(w=base.pen_width)
  }
  writer.write_word(w=base.layer)
  writer.write_word(w=base.layer_group)
  writer.write_word(w=base.flag)
}

///|
/// 文字列を ASCII バイト列に変換
fn string_to_ascii(s~ : String) -> Bytes {
  let bytes = Array::new()
  for c in s.to_array() {
    bytes.push(c.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}
