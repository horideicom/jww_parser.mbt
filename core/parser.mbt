///|
/// JWWファイルパーサー

///|
/// JWWシグネチャ
fn signature() -> Bytes {
  b"JwwData."
}

///|
/// JWWファイルをパースする
pub fn parse(data~ : Bytes) -> Document {
  // シグネチャ検証
  if data.length() < 8 {
    return Document::default()
  }

  let sig = Bytes::from_array(data.to_array()[0:8])
  if sig != signature() {
    return Document::default()
  }

  let reader = Reader::new(data=Bytes::from_array(data.to_array()[8:data.length()]))

  // バージョン読み取り
  let version = reader.read_dword()

  // ヘッダー情報読み取り
  let memo = read_cstring(reader=reader)
  let paper_size = reader.read_dword()
  let write_layer_group = reader.read_dword()

  // レイヤグループ読み取り (16グループ)
  let layer_groups = Array::new()
  for _g_idx in 0..<16 {
    let state = reader.read_dword()
    let write_layer = reader.read_dword()
    let scale = reader.read_double()
    let protect = reader.read_dword()

    let layers = Array::new()
    for _l_idx in 0..<16 {
      let lay_state = reader.read_dword()
      let lay_protect = reader.read_dword()
      layers.push({ state: lay_state, protect: lay_protect, name: "" })
    }

    layer_groups.push({
      state: state,
      write_layer: write_layer,
      scale: scale,
      protect: protect,
      layers: layers,
      name: ""
    })
  }

  // エンティティリスト開始位置を探索
  let entity_offset = find_entity_list_offset(data=data, version=version)

  let entities = match entity_offset {
    Some(offset) => parse_entity_list(data=data, offset=offset, version=version)
    None => Array::new()
  }

  // レイヤー名を設定
  let named_layer_groups = set_layer_names(layer_groups=layer_groups)

  {
    version: version,
    memo: memo,
    paper_size: paper_size,
    write_layer_group: write_layer_group,
    layer_groups: named_layer_groups,
    entities: entities,
    block_defs: Array::new()
  }
}

///|
/// MFC CString形式で文字列を読み込む
fn read_cstring(reader~ : Reader) -> String {
  let len_byte = reader.read_byte().to_int()

  let length = if len_byte < 0xFF {
    len_byte
  } else {
    let len_word = reader.read_word().to_int()
    if len_word < 0xFFFF {
      len_word
    } else {
      reader.read_dword().reinterpret_as_int()
    }
  }

  if length == 0 {
    return ""
  }

  let bytes = reader.read_bytes(n=length)
  shift_jis_to_utf8(data=bytes)
}

///|
/// レイヤー名を設定する
fn set_layer_names(layer_groups~ : Array[LayerGroup]) -> Array[LayerGroup] {
  let result = Array::new()
  for g_idx in 0..<layer_groups.length() {
    let lg = layer_groups[g_idx]
    let group_name = if lg.name == "" {
      "Group" + g_idx.to_string()
    } else {
      lg.name
    }

    let layers = Array::new()
    for l_idx in 0..<lg.layers.length() {
      let l = lg.layers[l_idx]
      let layer_name = if l.name == "" {
        g_idx.to_string() + "-" + l_idx.to_string()
      } else {
        l.name
      }
      let new_layer = {
        state: l.state,
        protect: l.protect,
        name: layer_name
      }
      layers.push(new_layer)
    }

    let new_group = {
      state: lg.state,
      write_layer: lg.write_layer,
      scale: lg.scale,
      protect: lg.protect,
      layers: layers,
      name: group_name
    }
    result.push(new_group)
  }
  result
}

///|
/// エンティティリストの開始位置を探索する
fn find_entity_list_offset(data~ : Bytes, version~ : UInt) -> Option[Int] {
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

          if c0 == 'C'.to_int() && c1 == 'D'.to_int() && c2 == 'a'.to_int() && c3 == 't'.to_int() && c4 == 'a'.to_int() {
            // 最初のエンティティクラス定義が見つかった
            // カウントWORDは直前（2バイト前）
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
/// エンティティリストをパースする
fn parse_entity_list(data~ : Bytes, offset~ : Int, version~ : UInt) -> Array[Entity] {
  let entity_data = Bytes::from_array(data.to_array()[offset:data.length()])
  let reader = Reader::new(data=entity_data)

  let count = reader.read_word().to_int()

  let entities = Array::new()

  // MFC CArchive PIDトラッキング - 簡易実装のためHashMapは使用せず配列で管理
  let mut pid_to_class = Array::new()
  for _ in 0..<256 {
    pid_to_class.push("")
  }
  let mut next_pid : UInt = 1U

  for _ in 0..<count {
    let result = parse_entity_with_pid_tracking(reader=reader, version=version, pid_to_class=pid_to_class, next_pid=next_pid)
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

  entities
}

///|
/// PIDトラッキング結果
priv struct PidTrackingResult {
  entity : Option[Entity]
  pid_to_class : Array[String]
  next_pid : UInt
}

///|
/// PIDトラッキング付きでエンティティをパースする
fn parse_entity_with_pid_tracking(
  reader~ : Reader,
  version~ : UInt,
  pid_to_class~ : Array[String],
  next_pid~ : UInt
) -> PidTrackingResult {
  let class_id = reader.read_word().to_int()

  let (class_name, updated_p2c, updated_next_pid) = if class_id == 0xFFFF {
    // 新しいクラス定義
    let _schema = reader.read_word()
    let name_len = reader.read_word().to_int()
    let name_bytes = reader.read_bytes(n=name_len)

    // バイト列をASCII文字列として解釈
    let mut name_chars = ""
    for i in 0..<name_bytes.length() {
      name_chars = name_chars + name_bytes[i].to_char().to_string()
    }
    let class_name = name_chars

    // PIDを登録
    let pid = next_pid
    let new_p2c = pid_to_class
    if pid.reinterpret_as_int() < 256 {
      new_p2c[pid.reinterpret_as_int()] = class_name
    }
    (class_name, new_p2c, pid + 1)
  } else if class_id == 0x8000 {
    // Nullオブジェクト
    return { entity: None, pid_to_class: pid_to_class, next_pid: next_pid + 1 }
  } else {
    // クラス参照: 0x8000 | class_pid
    let class_pid = (class_id & 0x7FFF)
    if class_pid < 256 {
      let name = pid_to_class[class_pid]
      if name == "" {
        return { entity: None, pid_to_class: pid_to_class, next_pid: next_pid + 1 }
      }
      (name, pid_to_class, next_pid)
    } else {
      return { entity: None, pid_to_class: pid_to_class, next_pid: next_pid + 1 }
    }
  }

  // クラス名に応じてエンティティをパース
  let entity = parse_entity_by_class(class_name=class_name, reader=reader, version=version)

  { entity: entity, pid_to_class: updated_p2c, next_pid: updated_next_pid + 1 }
}

///|
/// クラス名に応じてエンティティをパースする
fn parse_entity_by_class(
  class_name~ : String,
  reader~ : Reader,
  version~ : UInt
) -> Option[Entity] {
  if class_name == "CDataSen" {
    let base = parse_entity_base(reader=reader, version=version)
    let start_x = reader.read_double()
    let start_y = reader.read_double()
    let end_x = reader.read_double()
    let end_y = reader.read_double()
    Some(Entity::Line({
      base: base,
      start_x: start_x,
      start_y: start_y,
      end_x: end_x,
      end_y: end_y
    }))
  } else if class_name == "CDataEnko" {
    let base = parse_entity_base(reader=reader, version=version)
    let center_x = reader.read_double()
    let center_y = reader.read_double()
    let radius = reader.read_double()
    let start_angle = reader.read_double()
    let arc_angle = reader.read_double()
    let tilt_angle = reader.read_double()
    let flatness = reader.read_double()
    let full_circle = reader.read_dword()
    Some(Entity::Arc({
      base: base,
      center_x: center_x,
      center_y: center_y,
      radius: radius,
      start_angle: start_angle,
      arc_angle: arc_angle,
      tilt_angle: tilt_angle,
      flatness: flatness,
      is_full_circle: full_circle != 0
    }))
  } else if class_name == "CDataTen" {
    let base = parse_entity_base(reader=reader, version=version)
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

    Some(Entity::Point({
      base: base,
      x: x,
      y: y,
      is_temporary: is_temporary,
      code: code,
      angle: angle,
      scale: scale
    }))
  } else if class_name == "CDataMoji" {
    let base = parse_entity_base(reader=reader, version=version)
    let start_x = reader.read_double()
    let start_y = reader.read_double()
    let end_x = reader.read_double()
    let end_y = reader.read_double()
    let text_type = reader.read_dword()
    let size_x = reader.read_double()
    let size_y = reader.read_double()
    let spacing = reader.read_double()
    let angle = reader.read_double()
    let font_name = read_cstring(reader=reader)
    let content = read_cstring(reader=reader)
    Some(Entity::Text({
      base: base,
      start_x: start_x,
      start_y: start_y,
      end_x: end_x,
      end_y: end_y,
      text_type: text_type,
      size_x: size_x,
      size_y: size_y,
      spacing: spacing,
      angle: angle,
      font_name: font_name,
      content: content
    }))
  } else if class_name == "CDataSolid" {
    let base = parse_entity_base(reader=reader, version=version)
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

    Some(Entity::Solid({
      base: base,
      point1_x: point1_x,
      point1_y: point1_y,
      point2_x: point2_x,
      point2_y: point2_y,
      point3_x: point3_x,
      point3_y: point3_y,
      point4_x: point4_x,
      point4_y: point4_y,
      color: color
    }))
  } else if class_name == "CDataBlock" {
    let base = parse_entity_base(reader=reader, version=version)
    let ref_x = reader.read_double()
    let ref_y = reader.read_double()
    let scale_x = reader.read_double()
    let scale_y = reader.read_double()
    let rotation = reader.read_double()
    let def_number = reader.read_dword()
    Some(Entity::Block({
      base: base,
      ref_x: ref_x,
      ref_y: ref_y,
      scale_x: scale_x,
      scale_y: scale_y,
      rotation: rotation,
      def_number: def_number
    }))
  } else if class_name == "CDataSunpou" {
    // 寸法エンティティ - スキップ
    let _base = parse_entity_base(reader=reader, version=version)
    // 線メンバーをパース
    let _line_base = parse_entity_base(reader=reader, version=version)
    let _start_x = reader.read_double()
    let _start_y = reader.read_double()
    let _end_x = reader.read_double()
    let _end_y = reader.read_double()
    // 文字メンバーをパース（スキップ）
    let _text_base = parse_entity_base(reader=reader, version=version)
    let _text_start_x = reader.read_double()
    let _text_start_y = reader.read_double()
    let _text_end_x = reader.read_double()
    let _text_end_y = reader.read_double()
    let _text_type = reader.read_dword()
    let _text_size_x = reader.read_double()
    let _text_size_y = reader.read_double()
    let _text_spacing = reader.read_double()
    let _text_angle = reader.read_double()
    let _text_font_name = read_cstring(reader=reader)
    let _text_content = read_cstring(reader=reader)

    // Ver 4.20+ の追加データ
    if version >= 420 {
      let _sxf_mode = reader.read_word()
      for _ in 0..<2 {
        let _ = parse_entity_base(reader=reader, version=version)
        let _ = reader.read_double()
        let _ = reader.read_double()
        let _ = reader.read_double()
        let _ = reader.read_double()
      }
      for _ in 0..<4 {
        let _ = parse_entity_base(reader=reader, version=version)
        let _ = reader.read_double()
        let _ = reader.read_double()
        let _ = reader.read_dword()
      }
    }
    // 寸法はスキップ
    None
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

  let pen_width = if version >= 351 {
    reader.read_word()
  } else {
    0
  }

  let layer = reader.read_word()
  let layer_group = reader.read_word()
  let flag = reader.read_word()

  {
    group: group,
    pen_style: pen_style,
    pen_color: pen_color,
    pen_width: pen_width,
    layer: layer,
    layer_group: layer_group,
    flag: flag
  }
}
