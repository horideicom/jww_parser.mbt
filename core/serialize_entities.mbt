///|
/// エンティティのクラス名を取得
fn entity_class_name(entity~ : Entity) -> String {
  match entity {
    Line(_) => "CDataSen"
    Arc(_) => "CDataEnko"
    Point(_) => "CDataTen"
    Text(_) => "CDataMoji"
    Solid(_) => "CDataSolid"
    ArcSolid(_) => "CDataSolid"
    Block(_) => "CDataBlock"
    Image(_) => "CDataMoji" // 画像はCDataMoji形式で書き込む
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
    ArcSolid(arc_solid) => write_arc_solid(writer~, arc_solid~, version~)
    Block(block) => write_block(writer~, block~, version~)
    Image(image) => write_image(writer~, image~, version~)
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
/// 円弧/円ソリッドを書き込む
fn write_arc_solid(
  writer~ : Writer,
  arc_solid~ : ArcSolid,
  version~ : UInt,
) -> Unit {
  write_entity_base(writer~, base=arc_solid.base, version~)
  writer.write_double(d=arc_solid.center_x)
  writer.write_double(d=arc_solid.center_y)
  writer.write_double(d=arc_solid.radius)
  writer.write_double(d=arc_solid.flatness)
  writer.write_double(d=arc_solid.tilt_angle)
  writer.write_double(d=arc_solid.start_angle)
  writer.write_double(d=arc_solid.arc_angle)
  writer.write_double(d=arc_solid.solid_param)
  if arc_solid.base.pen_color == 10 {
    writer.write_dword(d=arc_solid.color)
  }
}

///|
/// ブロック挿入を書き込む
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
/// 画像を書き込む
fn write_image(writer~ : Writer, image~ : Image, version~ : UInt) -> Unit {
  write_entity_base(writer~, base=image.base, version~)
  writer.write_double(d=image.x)
  writer.write_double(d=image.y)
  writer.write_double(d=image.x + image.width) // end_x
  writer.write_double(d=image.y + image.height) // end_y
  writer.write_dword(d=0U) // text_type
  writer.write_double(d=image.width) // size_x
  writer.write_double(d=image.height) // size_y
  writer.write_double(d=0.0) // spacing
  writer.write_double(d=image.rotation) // angle
  write_cstring(writer~, s="") // font_name
  // ^@BM形式のコンテンツを構築
  let content = "^@BM" +
    image.image_path +
    "," +
    image.width.to_string() +
    "," +
    image.height.to_string()
  write_cstring(writer~, s=content)
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
