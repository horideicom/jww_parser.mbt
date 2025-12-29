///|
/// JWWからDXFへの変換ロジック

///|
/// 円周率
fn pi_value() -> Double {
  3.141592653589793
}

///|
/// JWWドキュメントをDXFドキュメントに変換する
pub fn convert_document(jww_doc~ : @core.Document) -> DxfDocument {
  let layers = convert_layers(jww_doc=jww_doc)
  let entities = convert_entities(jww_doc=jww_doc)
  let blocks = convert_blocks(jww_doc=jww_doc)

  {
    layers: layers,
    entities: entities,
    blocks: blocks
  }
}

///|
/// JWWレイヤーをDXFレイヤーに変換する
fn convert_layers(jww_doc~ : @core.Document) -> Array[DxfLayer] {
  let layers = Array::new()

  for g_idx in 0..<16 {
    let lg = jww_doc.layer_groups[g_idx]
    for l_idx in 0..<16 {
      let l = lg.layers[l_idx]
      let name = if l.name == "" {
        g_idx.to_string() + "-" + l_idx.to_string()
      } else {
        l.name
      }

      layers.push({
        name: name,
        color: ((g_idx * 16 + l_idx) % 255 + 1),
        line_type: "CONTINUOUS",
        frozen: l.state == 0,
        locked: l.protect != 0
      })
    }
  }

  layers
}

///|
/// JWWエンティティをDXFエンティティに変換する
fn convert_entities(jww_doc~ : @core.Document) -> Array[DxfEntity] {
  let entities = Array::new()

  for jww_entity in jww_doc.entities {
    match convert_entity(entity=jww_entity, jww_doc=jww_doc) {
      Some(dxf_entity) => entities.push(dxf_entity)
      None => ()
    }
  }

  entities
}

///|
/// 単一のJWWエンティティをDXFエンティティに変換する
fn convert_entity(entity~ : @core.Entity, jww_doc~ : @core.Document) -> Option[DxfEntity] {
  let base = @core.Entity::base(entity)
  let layer_name = get_layer_name(jww_doc=jww_doc, layer_group=base.layer_group, layer=base.layer)
  let color = map_color(jww_color=base.pen_color)
  let line_type = map_line_type(pen_style=base.pen_style)

  match entity {
    @core.Line(line) => {
      Some(DxfEntity::Line({
        layer: layer_name,
        color: color,
        line_type: line_type,
        x1: line.start_x,
        y1: line.start_y,
        x2: line.end_x,
        y2: line.end_y
      }))
    }
    @core.Arc(arc) => {
      if arc.is_full_circle && arc.flatness == 1.0 {
        // 完全円
        Some(DxfEntity::Circle({
          layer: layer_name,
          color: color,
          line_type: line_type,
          center_x: arc.center_x,
          center_y: arc.center_y,
          radius: arc.radius
        }))
      } else if arc.flatness != 1.0 {
        // 楕円または楕円弧
        let major_radius = arc.radius
        let minor_ratio = arc.flatness
        let tilt_angle = arc.tilt_angle

        let (major_radius, minor_ratio, tilt_angle) = if minor_ratio > 1.0 {
          // 軸を入れ替え
          (arc.radius * arc.flatness, 1.0 / arc.flatness, arc.tilt_angle + pi_value() / 2.0)
        } else {
          (major_radius, minor_ratio, tilt_angle)
        }

        let major_axis_x = major_radius * tilt_angle
        let major_axis_y = major_radius * tilt_angle

        let (start_param, end_param) = if arc.is_full_circle {
          (0.0, 2.0 * pi_value())
        } else {
          (arc.start_angle, arc.start_angle + arc.arc_angle)
        }

        Some(DxfEntity::Ellipse({
          layer: layer_name,
          color: color,
          line_type: line_type,
          center_x: arc.center_x,
          center_y: arc.center_y,
          major_axis_x: major_axis_x,
          major_axis_y: major_axis_y,
          minor_ratio: minor_ratio,
          start_param: start_param,
          end_param: end_param
        }))
      } else {
        // 円弧
        let start_angle = rad_to_deg(rad=arc.start_angle)
        let end_angle = rad_to_deg(rad=arc.start_angle + arc.arc_angle)

        Some(DxfEntity::Arc({
          layer: layer_name,
          color: color,
          line_type: line_type,
          center_x: arc.center_x,
          center_y: arc.center_y,
          radius: arc.radius,
          start_angle: start_angle,
          end_angle: end_angle
        }))
      }
    }
    @core.Point(point) => {
      if point.is_temporary {
        None  // 仮点はスキップ
      } else {
        Some(DxfEntity::Point({
          layer: layer_name,
          color: color,
          line_type: line_type,
          x: point.x,
          y: point.y
        }))
      }
    }
    @core.Text(text) => {
      let height = if text.size_y <= 0.0 { 2.5 } else { text.size_y }

      Some(DxfEntity::Text({
        layer: layer_name,
        color: color,
        line_type: line_type,
        x: text.start_x,
        y: text.start_y,
        height: height,
        rotation: text.angle,
        content: text.content,
        style: "STANDARD"
      }))
    }
    @core.Solid(solid) => {
      Some(DxfEntity::Solid({
        layer: layer_name,
        color: color,
        line_type: line_type,
        x1: solid.point1_x,
        y1: solid.point1_y,
        x2: solid.point2_x,
        y2: solid.point2_y,
        x3: solid.point3_x,
        y3: solid.point3_y,
        x4: solid.point4_x,
        y4: solid.point4_y
      }))
    }
    @core.Block(block) => {
      let block_name = get_block_name(jww_doc=jww_doc, def_number=block.def_number)
      Some(DxfEntity::Insert({
        layer: layer_name,
        color: color,
        line_type: line_type,
        block_name: block_name,
        x: block.ref_x,
        y: block.ref_y,
        scale_x: block.scale_x,
        scale_y: block.scale_y,
        rotation: rad_to_deg(rad=block.rotation)
      }))
    }
  }
}

///|
/// JWWブロック定義をDXFブロックに変換する
fn convert_blocks(jww_doc~ : @core.Document) -> Array[DxfBlock] {
  let blocks = Array::new()

  for bd in jww_doc.block_defs {
    let block_entities = Array::new()

    for e in bd.entities {
      match convert_entity(entity=e, jww_doc=jww_doc) {
        Some(dxf_entity) => block_entities.push(dxf_entity)
        None => ()
      }
    }

    blocks.push({
      name: bd.name,
      base_x: 0.0,
      base_y: 0.0,
      entities: block_entities
    })
  }

  blocks
}

///|
/// レイヤー名を取得する
fn get_layer_name(jww_doc~ : @core.Document, layer_group~ : UInt16, layer~ : UInt16) -> String {
  let lg = layer_group
  let l = layer

  if lg < 16 && l < 16 {
    let layer_group_data = jww_doc.layer_groups[lg.to_int()]
    let layer_data = layer_group_data.layers[l.to_int()]
    if layer_data.name != "" {
      return layer_data.name
    }
  }

  lg.to_string() + "-" + l.to_string()
}

///|
/// ブロック名を取得する
fn get_block_name(jww_doc~ : @core.Document, def_number~ : UInt) -> String {
  for bd in jww_doc.block_defs {
    if bd.number == def_number {
      if bd.name != "" {
        return bd.name
      }
    }
  }
  "BLOCK_" + def_number.to_string()
}

///|
/// JWW色コードをDXF ACI値にマッピングする
fn map_color(jww_color~ : UInt16) -> Int {
  match jww_color {
    0 => 0     // BYLAYER
    1 => 4     // JWW 水色 -> DXF cyan
    2 => 7     // JWW 白 -> DXF white
    3 => 3     // JWW 緑 -> DXF green
    4 => 2     // JWW 黄色 -> DXF yellow
    5 => 6     // JWW ピンク -> DXF magenta
    6 => 5     // JWW 青 -> DXF blue
    7 => 7     // JWW 黒/白 -> DXF white/black
    8 => 1     // JWW 赤 -> DXF red
    9 => 8     // JWW グレー -> DXF gray
    c => {
      if c >= 100 {
        (c.to_int() - 100 + 10)
      } else {
        c.to_int()
      }
    }
  }
}

///|
/// JWW線種をDXF線種名にマッピングする
fn map_line_type(pen_style~ : Byte) -> String {
  match pen_style {
    0 | 1 => "CONTINUOUS"
    2 => "DASHED"
    3 => "DASHDOT"
    4 => "CENTER"
    5 => "DOT"
    6 => "DASHEDX2"
    7 => "DASHDOTX2"
    8 => "CENTERX2"
    9 => "DOTX2"
    _ => "CONTINUOUS"
  }
}

///|
/// ラジアンを度に変換する
fn rad_to_deg(rad~ : Double) -> Double {
  rad * 180.0 / pi_value()
}
