///|
/// JWWドキュメントJSONシリアライザー

///|
/// JSON文字列をエスケープする
fn escape_string(s : String) -> String {
  let chars = s.to_array()
  let mut result = "\""
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '"' {
      result = result + "\\\""
    } else if c == '\\' {
      result = result + "\\\\"
    } else if c == '\n' {
      result = result + "\\n"
    } else if c == '\t' {
      result = result + "\\t"
    } else if c == '\r' {
      result = result + "\\r"
    } else {
      let code = c.to_int()
      if code < 32 {
        // 制御文字は \uXXXX 形式でエスケープ
        let hex = "0123456789ABCDEF"
        let h1 = (code >> 12) & 0xF
        let h2 = (code >> 8) & 0xF
        let h3 = (code >> 4) & 0xF
        let h4 = code & 0xF
        result = result + "\\u" + hex[h1].to_string() + hex[h2].to_string() + hex[h3].to_string() + hex[h4].to_string()
      } else {
        result = result + c.to_string()
      }
    }
    i = i + 1
  }
  result + "\""
}

///|
/// EntityBaseをJSONに変換
fn entity_base_to_json(base : EntityBase) -> String {
  "{" +
    "\"group\":" + base.group.to_string() +
    ",\"pen_style\":" + base.pen_style.to_int().to_string() +
    ",\"pen_color\":" + base.pen_color.to_int().to_string() +
    ",\"pen_width\":" + base.pen_width.to_int().to_string() +
    ",\"layer\":" + base.layer.to_int().to_string() +
    ",\"layer_group\":" + base.layer_group.to_int().to_string() +
    ",\"flag\":" + base.flag.to_int().to_string() +
  "}"
}

///|
/// EntityをJSONに変換
pub fn entity_to_json(entity : Entity) -> String {
  match entity {
    Line(line) => {
      "{\"type\":\"Line\",\"base\":" + entity_base_to_json(line.base) +
      ",\"start_x\":" + line.start_x.to_string() +
      ",\"start_y\":" + line.start_y.to_string() +
      ",\"end_x\":" + line.end_x.to_string() +
      ",\"end_y\":" + line.end_y.to_string() +
      "}"
    }
    Arc(arc) => {
      let type_str = if arc.is_full_circle { "CIRCLE" } else { "ARC" }
      "{\"type\":\"" + type_str + "\",\"base\":" + entity_base_to_json(arc.base) +
      ",\"center_x\":" + arc.center_x.to_string() +
      ",\"center_y\":" + arc.center_y.to_string() +
      ",\"radius\":" + arc.radius.to_string() +
      ",\"start_angle\":" + arc.start_angle.to_string() +
      ",\"arc_angle\":" + arc.arc_angle.to_string() +
      ",\"tilt_angle\":" + arc.tilt_angle.to_string() +
      ",\"flatness\":" + arc.flatness.to_string() +
      ",\"is_full_circle\":" + (if arc.is_full_circle { "true" } else { "false" }) +
      "}"
    }
    Point(point) => {
      "{\"type\":\"Point\",\"base\":" + entity_base_to_json(point.base) +
      ",\"x\":" + point.x.to_string() +
      ",\"y\":" + point.y.to_string() +
      ",\"is_temporary\":" + (if point.is_temporary { "true" } else { "false" }) +
      ",\"code\":" + point.code.to_string() +
      ",\"angle\":" + point.angle.to_string() +
      ",\"scale\":" + point.scale.to_string() +
      "}"
    }
    Text(text) => {
      "{\"type\":\"Text\",\"base\":" + entity_base_to_json(text.base) +
      ",\"start_x\":" + text.start_x.to_string() +
      ",\"start_y\":" + text.start_y.to_string() +
      ",\"end_x\":" + text.end_x.to_string() +
      ",\"end_y\":" + text.end_y.to_string() +
      ",\"text_type\":" + text.text_type.to_string() +
      ",\"size_x\":" + text.size_x.to_string() +
      ",\"size_y\":" + text.size_y.to_string() +
      ",\"spacing\":" + text.spacing.to_string() +
      ",\"angle\":" + text.angle.to_string() +
      ",\"font_name\":" + escape_string(text.font_name) +
      ",\"content\":" + escape_string(text.content) +
      "}"
    }
    Solid(solid) => {
      "{\"type\":\"Solid\",\"base\":" + entity_base_to_json(solid.base) +
      ",\"point1_x\":" + solid.point1_x.to_string() +
      ",\"point1_y\":" + solid.point1_y.to_string() +
      ",\"point2_x\":" + solid.point2_x.to_string() +
      ",\"point2_y\":" + solid.point2_y.to_string() +
      ",\"point3_x\":" + solid.point3_x.to_string() +
      ",\"point3_y\":" + solid.point3_y.to_string() +
      ",\"point4_x\":" + solid.point4_x.to_string() +
      ",\"point4_y\":" + solid.point4_y.to_string() +
      ",\"color\":" + solid.color.to_string() +
      "}"
    }
    Block(block) => {
      "{\"type\":\"Block\",\"base\":" + entity_base_to_json(block.base) +
      ",\"ref_x\":" + block.ref_x.to_string() +
      ",\"ref_y\":" + block.ref_y.to_string() +
      ",\"scale_x\":" + block.scale_x.to_string() +
      ",\"scale_y\":" + block.scale_y.to_string() +
      ",\"rotation\":" + block.rotation.to_string() +
      ",\"def_number\":" + block.def_number.to_string() +
      "}"
    }
    Image(image) => {
      "{\"type\":\"Image\",\"base\":" + entity_base_to_json(image.base) +
      ",\"image_path\":" + escape_string(image.image_path) +
      ",\"x\":" + image.x.to_string() +
      ",\"y\":" + image.y.to_string() +
      ",\"width\":" + image.width.to_string() +
      ",\"height\":" + image.height.to_string() +
      ",\"rotation\":" + image.rotation.to_string() +
      "}"
    }
  }
}

///|
/// LayerをJSONに変換
fn layer_to_json(layer : Layer) -> String {
  "{" +
    "\"state\":" + layer.state.to_string() +
    ",\"protect\":" + layer.protect.to_string() +
    ",\"name\":" + escape_string(layer.name) +
  "}"
}

///|
/// LayerGroupをJSONに変換
fn layer_group_to_json(lg : LayerGroup) -> String {
  let mut layers_str = "["
  let mut first = true
  let mut i = 0
  while i < lg.layers.length() {
    let s = layer_to_json(lg.layers[i])
    if first {
      layers_str = layers_str + s
      first = false
    } else {
      layers_str = layers_str + "," + s
    }
    i = i + 1
  }
  layers_str = layers_str + "]"

  "{" +
    "\"state\":" + lg.state.to_string() +
    ",\"write_layer\":" + lg.write_layer.to_string() +
    ",\"scale\":" + lg.scale.to_string() +
    ",\"protect\":" + lg.protect.to_string() +
    ",\"name\":" + escape_string(lg.name) +
    ",\"layers\":" + layers_str +
  "}"
}

///|
/// BlockDefをJSONに変換
fn block_def_to_json(bd : BlockDef) -> String {
  let mut entities_str = "["
  let mut first = true
  let mut i = 0
  while i < bd.entities.length() {
    let s = entity_to_json(bd.entities[i])
    if first {
      entities_str = entities_str + s
      first = false
    } else {
      entities_str = entities_str + "," + s
    }
    i = i + 1
  }
  entities_str = entities_str + "]"

  "{" +
    "\"base\":" + entity_base_to_json(bd.base) +
    ",\"number\":" + bd.number.to_string() +
    ",\"is_referenced\":" + (if bd.is_referenced { "true" } else { "false" }) +
    ",\"name\":" + escape_string(bd.name) +
    ",\"entities\":" + entities_str +
  "}"
}

///|
/// EmbeddedImageをJSONに変換
fn embedded_image_to_json(ei : EmbeddedImage) -> String {
  "{" +
    "\"index\":" + ei.index.to_string() +
    ",\"file_size\":" + ei.file_size.to_string() +
    ",\"format\":" + image_format_to_json(ei.format) +
  "}"
}

///|
/// ImageFormatをJSONに変換
fn image_format_to_json(format : ImageFormat) -> String {
  match format {
    Unknown => "\"Unknown\""
    Jpeg => "\"Jpeg\""
    Png => "\"Png\""
    Bmp => "\"Bmp\""
    Gif => "\"Gif\""
  }
}

///|
/// PrintSettingsをJSONに変換
fn print_settings_to_json(ps : PrintSettings) -> String {
  "{" +
    "\"origin_x\":" + ps.origin_x.to_string() +
    ",\"origin_y\":" + ps.origin_y.to_string() +
    ",\"scale\":" + ps.scale.to_string() +
    ",\"rotation_setting\":" + ps.rotation_setting.to_string() +
  "}"
}

///|
/// SunpouSettingsをJSONに変換
fn sunpou_settings_to_json(ss : SunpouSettings) -> String {
  "{" +
    "\"sunpou1\":" + ss.sunpou1.to_string() +
    ",\"sunpou2\":" + ss.sunpou2.to_string() +
    ",\"sunpou3\":" + ss.sunpou3.to_string() +
    ",\"sunpou4\":" + ss.sunpou4.to_string() +
    ",\"sunpou5\":" + ss.sunpou5.to_string() +
    ",\"dummy\":" + ss.dummy.to_string() +
    ",\"max_line_width\":" + ss.max_line_width.to_string() +
  "}"
}

///|
/// MetadataSettingsをJSONに変換
fn metadata_settings_to_json(ms : MetadataSettings) -> String {
  "{" +
    "\"printer_paper_size\":" + escape_string(ms.printer_paper_size) +
    ",\"draw_bmp_touka\":" + escape_string(ms.draw_bmp_touka) +
    ",\"view_direct2d\":" + escape_string(ms.view_direct2d) +
    ",\"printer_bmp_zentai\":" + escape_string(ms.printer_bmp_zentai) +
    ",\"printer_orientation\":" + escape_string(ms.printer_orientation) +
    ",\"printer_d2d_bmp\":" + escape_string(ms.printer_d2d_bmp) +
  "}"
}

///|
/// エンティティ配列をJSON配列に変換
fn entities_to_json_array(entities : Array[Entity]) -> String {
  let mut result = "["
  let mut first = true
  let mut i = 0
  while i < entities.length() {
    let s = entity_to_json(entities[i])
    if first {
      result = result + s
      first = false
    } else {
      result = result + "," + s
    }
    i = i + 1
  }
  result + "]"
}

///|
/// レイヤグループ配列をJSON配列に変換
fn layer_groups_to_json_array(layer_groups : Array[LayerGroup]) -> String {
  let mut result = "["
  let mut first = true
  let mut i = 0
  while i < layer_groups.length() {
    let s = layer_group_to_json(layer_groups[i])
    if first {
      result = result + s
      first = false
    } else {
      result = result + "," + s
    }
    i = i + 1
  }
  result + "]"
}

///|
/// ブロック定義配列をJSON配列に変換
fn block_defs_to_json_array(block_defs : Array[BlockDef]) -> String {
  let mut result = "["
  let mut first = true
  let mut i = 0
  while i < block_defs.length() {
    let s = block_def_to_json(block_defs[i])
    if first {
      result = result + s
      first = false
    } else {
      result = result + "," + s
    }
    i = i + 1
  }
  result + "]"
}

///|
/// 同梱画像配列をJSON配列に変換
fn embedded_images_to_json_array(embedded_images : Array[EmbeddedImage]) -> String {
  let mut result = "["
  let mut first = true
  let mut i = 0
  while i < embedded_images.length() {
    let s = embedded_image_to_json(embedded_images[i])
    if first {
      result = result + s
      first = false
    } else {
      result = result + "," + s
    }
    i = i + 1
  }
  result + "]"
}

///|
/// DocumentをJSON文字列に変換
pub fn document_to_json(doc : Document) -> String {
  "{" +
    "\"version\":" + doc.version.to_string() +
    ",\"memo\":" + escape_string(doc.memo) +
    ",\"paper_size\":" + doc.paper_size.to_string() +
    ",\"write_layer_group\":" + doc.write_layer_group.to_string() +
    ",\"layer_groups\":" + layer_groups_to_json_array(doc.layer_groups) +
    ",\"entities\":" + entities_to_json_array(doc.entities) +
    ",\"block_defs\":" + block_defs_to_json_array(doc.block_defs) +
    ",\"embedded_images\":" + embedded_images_to_json_array(doc.embedded_images) +
    ",\"print_settings\":" + print_settings_to_json(doc.print_settings) +
    ",\"sunpou_settings\":" + sunpou_settings_to_json(doc.sunpou_settings) +
    ",\"metadata_settings\":" + metadata_settings_to_json(doc.metadata_settings) +
  "}"
}
