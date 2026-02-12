///|
/// エンティティリストの開始位置を探索する
fn find_entity_list_offset(data~ : Bytes, version~ : UInt) -> Int? {
  let schema_low = (version & 0xFFU).reinterpret_as_int()
  let schema_high = ((version >> 8) & 0xFFU).reinterpret_as_int()
  let search_start = 100
  let search_end = data.length() - 20
  let mut i = search_start
  while i < search_end {
    // 0xFF 0xFF (新しいクラス定義マーカー) を検索
    let b0 = data[i].to_int()
    let b1 = data[i + 1].to_int()
    if b0 == 0xFF && b1 == 0xFF {
      // スキーマバージョンが一致するか確認
      let s0 = data[i + 2].to_int()
      let s1 = data[i + 3].to_int()
      if s0 == schema_low && s1 == schema_high {
        // クラス名長さを取得
        let name_len = data[i + 4].to_int() | (data[i + 5].to_int() << 8)
        if name_len >= 8 && name_len <= 20 && i + 6 + name_len <= data.length() {
          // "CData"で始まるかチェック
          let c0 = data[i + 6].to_int()
          let c1 = data[i + 7].to_int()
          let c2 = data[i + 8].to_int()
          let c3 = data[i + 9].to_int()
          let c4 = data[i + 10].to_int()
          if c0 == 'C'.to_int() &&
            c1 == 'D'.to_int() &&
            c2 == 'a'.to_int() &&
            c3 == 't'.to_int() &&
            c4 == 'a'.to_int() {
            // 最初のエンティティクラス定義が見つかった
            // カウントWORDは2バイト前
            return Some(i - 2)
          }
        }
      }
    }
    i += 1
  }
  None
}

///|
/// エンティティリストパース結果
priv struct EntityListResult {
  entities : Array[Entity]
  bytes_consumed : Int
}

///|
/// エンティティリストをパースする
fn parse_entity_list(
  data~ : Bytes,
  offset~ : Int,
  version~ : UInt,
) -> EntityListResult {
  let entity_data = Bytes::from_array(data.to_array()[offset:data.length()])
  let reader = Reader::new(data=entity_data)
  let start_pos = reader.position()
  let count = reader.read_word().to_int()
  let entities = Array::new()

  // MFC CArchive PIDトラッキング
  // PIDはUInt16で最大65536まで可能なため、十分なサイズの配列を確保
  let mut pid_to_class = Array::new()
  for _ in 0..<65536 {
    pid_to_class.push("")
  }
  let mut next_pid : UInt = 1U
  for _ in 0..<count {
    // 残りデータが不足している場合は終了
    if reader.remaining() < 4 {
      break
    }
    let result = parse_entity_with_pid_tracking(
      reader~,
      version~,
      pid_to_class~,
      next_pid~,
    )
    match result {
      { entity: Some(ent), pid_to_class: p2c, next_pid: npid } => {
        entities.push(ent)
        pid_to_class = p2c
        next_pid = npid
      }
      { entity: None, pid_to_class: p2c, next_pid: npid } => {
        pid_to_class = p2c
        next_pid = npid
      }
    }
  }
  let end_pos = reader.position()
  { entities, bytes_consumed: end_pos - start_pos }
}

///|
/// PIDトラッキング結果
priv struct PidTrackingResult {
  entity : Entity?
  pid_to_class : Array[String]
  next_pid : UInt
}

///|
/// PIDトラッキング付きでエンティティをパースする
fn parse_entity_with_pid_tracking(
  reader~ : Reader,
  version~ : UInt,
  pid_to_class~ : Array[String],
  next_pid~ : UInt,
) -> PidTrackingResult {
  let class_id = reader.read_word().to_int()
  let mut class_name = ""
  let updated_p2c = pid_to_class
  let mut updated_next_pid = next_pid
  if class_id == 0xFFFF {
    // 新しいクラス定義 - クラス情報を読み取ってエンティティパースに進む
    let _schema = reader.read_word()
    let name_len = reader.read_word().to_int()
    let name_bytes = reader.read_bytes(n=name_len)

    // バイト列をASCII文字列として解釈
    let mut name_chars = ""
    for i in 0..<name_bytes.length() {
      name_chars = name_chars + name_bytes[i].to_char().to_string()
    }
    class_name = name_chars

    // PIDを登録
    let pid = updated_next_pid
    let pid_int = pid.reinterpret_as_int()
    if pid_int < 65536 {
      updated_p2c[pid_int] = class_name
    }
    updated_next_pid = pid + 1U
  } else if class_id == 0x8000 {
    // Nullオブジェクト
    return { entity: None, pid_to_class: updated_p2c, next_pid: next_pid + 1 }
  } else {
    // クラス参照: 0x8000 | class_pid
    let class_pid = class_id & 0x7FFF
    if class_pid < 65536 {
      let name = updated_p2c[class_pid]
      if name == "" {
        // 不明なクラス - データスキップ
        let _base = parse_entity_base(reader~, version~)
        let _skip1 = reader.read_double()
        let _skip2 = reader.read_double()
        let _skip3 = reader.read_double()
        let _skip4 = reader.read_double()
        return {
          entity: None,
          pid_to_class: updated_p2c,
          next_pid: next_pid + 1,
        }
      }
      class_name = name
    } else {
      // 不正なPID - エンティティデータをスキップ
      let _base = parse_entity_base(reader~, version~)
      let _skip1 = reader.read_double()
      let _skip2 = reader.read_double()
      let _skip3 = reader.read_double()
      let _skip4 = reader.read_double()
      return { entity: None, pid_to_class: updated_p2c, next_pid: next_pid + 1 }
    }
  }

  // クラス名に応じてエンティティをパース（0xFFFF以外の全ケース）
  let entity = parse_entity_by_class(class_name~, reader~, version~)
  { entity, pid_to_class: updated_p2c, next_pid: updated_next_pid + 1 }
}

///|
/// クラス名に応じてエンティティをパースする
fn parse_entity_by_class(
  class_name~ : String,
  reader~ : Reader,
  version~ : UInt,
) -> Entity? {
  if class_name == "CDataSen" {
    let base = parse_entity_base(reader~, version~)
    let start_x = reader.read_double()
    let start_y = reader.read_double()
    let end_x = reader.read_double()
    let end_y = reader.read_double()
    Some(Entity::Line({ base, start_x, start_y, end_x, end_y }))
  } else if class_name == "CDataEnko" {
    let base = parse_entity_base(reader~, version~)
    let center_x = reader.read_double()
    let center_y = reader.read_double()
    let radius = reader.read_double()
    let start_angle = reader.read_double()
    let arc_angle = reader.read_double()
    let tilt_angle = reader.read_double()
    let flatness = reader.read_double()
    let full_circle = reader.read_dword()
    Some(
      Entity::Arc({
        base,
        center_x,
        center_y,
        radius,
        start_angle,
        arc_angle,
        tilt_angle,
        flatness,
        is_full_circle: full_circle != 0,
      }),
    )
  } else if class_name == "CDataTen" {
    let base = parse_entity_base(reader~, version~)
    let x = reader.read_double()
    let y = reader.read_double()
    let tmp = reader.read_dword()
    let is_temporary = tmp != 0
    let mut code = 0U
    let mut angle = 0.0
    let mut scale = 1.0
    if base.pen_style == 100 {
      code = reader.read_dword()
      angle = reader.read_double()
      scale = reader.read_double()
    }
    Some(Entity::Point({ base, x, y, is_temporary, code, angle, scale }))
  } else if class_name == "CDataMoji" {
    let base = parse_entity_base(reader~, version~)
    let start_x = reader.read_double()
    let start_y = reader.read_double()
    let end_x = reader.read_double()
    let end_y = reader.read_double()
    let text_type = reader.read_dword()
    let size_x = reader.read_double()
    let size_y = reader.read_double()
    let spacing = reader.read_double()
    let angle = reader.read_double()
    let font_name = read_cstring(reader~)
    let content = read_cstring(reader~)
    // メタデータ設定はエンティティとして追加しない
    if is_metadata_text(content~) {
      None
      // ^@BMを含む場合は画像エンティティとして処理
    } else if find_bm_marker(content~) is Some(_) {
      match
        parse_image_from_bm_string(
          content~,
          base~,
          start_x~,
          start_y~,
          angle~,
          size_x~,
          size_y~,
        ) {
        Some(image) => Some(Entity::Image(image))
        None =>
          Some(
            Entity::Text({
              base,
              start_x,
              start_y,
              end_x,
              end_y,
              text_type,
              size_x,
              size_y,
              spacing,
              angle,
              font_name,
              content,
            }),
          )
      }
    } else {
      Some(
        Entity::Text({
          base,
          start_x,
          start_y,
          end_x,
          end_y,
          text_type,
          size_x,
          size_y,
          spacing,
          angle,
          font_name,
          content,
        }),
      )
    }
  } else if class_name == "CDataSolid" {
    let base = parse_entity_base(reader~, version~)
    let point1_x = reader.read_double()
    let point1_y = reader.read_double()
    let point4_x = reader.read_double()
    let point4_y = reader.read_double()
    let point2_x = reader.read_double()
    let point2_y = reader.read_double()
    let point3_x = reader.read_double()
    let point3_y = reader.read_double()
    let mut color = 0U
    if base.pen_color == 10 {
      color = reader.read_dword()
    }
    if base.pen_style.to_int() >= 101 {
      Some(
        Entity::ArcSolid({
          base,
          center_x: point1_x,
          center_y: point1_y,
          radius: point4_x,
          flatness: point4_y,
          tilt_angle: point2_x,
          start_angle: point2_y,
          arc_angle: point3_x,
          solid_param: point3_y,
          color,
        }),
      )
    } else {
      Some(
        Entity::Solid({
          base,
          point1_x,
          point1_y,
          point2_x,
          point2_y,
          point3_x,
          point3_y,
          point4_x,
          point4_y,
          color,
        }),
      )
    }
  } else if class_name == "CDataBlock" {
    let base = parse_entity_base(reader~, version~)
    let ref_x = reader.read_double()
    let ref_y = reader.read_double()
    let scale_x = reader.read_double()
    let scale_y = reader.read_double()
    let rotation = reader.read_double()
    let def_number = reader.read_dword()
    Some(
      Entity::Block({
        base,
        ref_x,
        ref_y,
        scale_x,
        scale_y,
        rotation,
        def_number,
      }),
    )
  } else if class_name == "CDataSunpou" {
    // 寸法エンティティ - 線メンバーを返す
    let _base = parse_entity_base(reader~, version~)
    // 線メンバーをパースして返す（Go版の実装に倣う）
    let line_base = parse_entity_base(reader~, version~)
    let start_x = reader.read_double()
    let start_y = reader.read_double()
    let end_x = reader.read_double()
    let end_y = reader.read_double()
    // 文字メンバーをパース（スキップ）
    let _text_base = parse_entity_base(reader~, version~)
    let _text_start_x = reader.read_double()
    let _text_start_y = reader.read_double()
    let _text_end_x = reader.read_double()
    let _text_end_y = reader.read_double()
    let _text_type = reader.read_dword()
    let _text_size_x = reader.read_double()
    let _text_size_y = reader.read_double()
    let _text_spacing = reader.read_double()
    let _text_angle = reader.read_double()
    let _text_font_name = read_cstring(reader~)
    let _text_content = read_cstring(reader~)

    // Ver 4.20+ の追加データ
    if version >= 420 {
      let _sxf_mode = reader.read_word()
      for _ in 0..<2 {
        let _ = parse_entity_base(reader~, version~)
        let _ = reader.read_double()
        let _ = reader.read_double()
        let _ = reader.read_double()
        let _ = reader.read_double()
      }
      for _ in 0..<4 {
        let _ = parse_entity_base(reader~, version~)
        let _ = reader.read_double()
        let _ = reader.read_double()
        let _ = reader.read_dword()
      }
    }
    // 寸法エンティティは線として返す（Go版の実装に倣う）
    Some(Entity::Line({ base: line_base, start_x, start_y, end_x, end_y }))
  } else {
    // 不明なクラス
    None
  }
}

///|
/// エンティティ基本属性をパースする
fn parse_entity_base(reader~ : Reader, version~ : UInt) -> EntityBase {
  let group = reader.read_dword()
  let pen_style = reader.read_byte()
  let pen_color = reader.read_word()
  let pen_width = if version >= 351 { reader.read_word() } else { 0 }
  let layer = reader.read_word()
  let layer_group = reader.read_word()
  let flag = reader.read_word()
  { group, pen_style, pen_color, pen_width, layer, layer_group, flag }
}
