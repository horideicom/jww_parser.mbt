///|
/// JWWファイルパーサー

///|
/// JWWシグネチャ
pub fn signature() -> Bytes {
  b"JwwData."
}

///|
/// 印刷設定をパースする
fn parse_print_settings(reader~ : Reader) -> PrintSettings {
  // 印刷出力範囲の基点(X,Y)
  let origin_x = reader.read_double()
  let origin_y = reader.read_double()

  // 印刷出力倍率
  let scale = reader.read_double()

  // 印刷90度回転・基準点位置
  let rotation_setting = reader.read_dword()

  {
    origin_x,
    origin_y,
    scale,
    rotation_setting,
  }
}

///|
/// 日光設定をパースする
fn parse_sunpou_settings(reader~ : Reader) -> SunpouSettings {
  // 14個のDWORDをスキップ（予備）
  for _ in 0..<14 {
    let _ = reader.read_dword()
  }

  // 日光設定 (m_lnSunpou1〜5)
  let sunpou1 = reader.read_dword()
  let sunpou2 = reader.read_dword()
  let sunpou3 = reader.read_dword()
  let sunpou4 = reader.read_dword()
  let sunpou5 = reader.read_dword()

  // 予備 (1個のDWORD)
  let dummy = reader.read_dword()

  // 線の最大幅
  let max_line_width = reader.read_dword()

  {
    sunpou1,
    sunpou2,
    sunpou3,
    sunpou4,
    sunpou5,
    dummy,
    max_line_width,
  }
}

///|
/// レイヤ名とグループ名をパースする
fn parse_layer_names(
  reader~ : Reader,
  layer_groups~ : Array[LayerGroup],
) -> Array[LayerGroup] {
  // parse_sunpou_settingsで既に日光設定等を読み取っているため、
  // ここではスキップ処理は不要

  // レイヤ名を256個読み取る (16グループ x 16レイヤ)
  let layer_names = Array::new()
  for _g_idx in 0..<16 {
    let group_layer_names = Array::new()
    for _l_idx in 0..<16 {
      let name = read_cstring(reader~)
      group_layer_names.push(name)
    }
    layer_names.push(group_layer_names)
  }

  // グループレイヤ名を16個読み取る
  let group_names = Array::new()
  for _g_idx in 0..<16 {
    let name = read_cstring(reader~)
    group_names.push(name)
  }

  // 読み取った名前をlayer_groupsに反映
  let result = Array::new()
  for g_idx in 0..<layer_groups.length() {
    let lg = layer_groups[g_idx]
    let group_name = group_names[g_idx]
    let layers = Array::new()
    for l_idx in 0..<lg.layers.length() {
      let l = lg.layers[l_idx]
      let layer_name = layer_names[g_idx][l_idx]
      let new_layer = { state: l.state, protect: l.protect, name: layer_name }
      layers.push(new_layer)
    }
    let new_group = {
      state: lg.state,
      write_layer: lg.write_layer,
      scale: lg.scale,
      protect: lg.protect,
      layers,
      name: group_name,
    }
    result.push(new_group)
  }
  result
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
  let reader = Reader::new(
    data=Bytes::from_array(data.to_array()[8:data.length()]),
  )

  // バージョン読み取り
  let version = reader.read_dword()

  // ヘッダー情報読み取り
  let memo = read_cstring(reader~)
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
    layer_groups.push({ state, write_layer, scale, protect, layers, name: "" })
  }

  // 印刷設定を読み取り
  let print_settings = parse_print_settings(reader~)

  // 日光設定を読み取り
  let sunpou_settings = parse_sunpou_settings(reader~)

  // レイヤ名を読み取り
  let layer_groups = parse_layer_names(reader~, layer_groups~)

  // エンティティリスト開始位置を探索
  let entity_offset = find_entity_list_offset(data~, version~)
  let (entities, block_defs, block_end_offset) = match entity_offset {
    Some(offset) => {
      let entity_result = parse_entity_list(data~, offset~, version~)
      // エンティティリストの直後にブロック定義リストがある
      let block_offset = offset + entity_result.bytes_consumed
      let block_result = parse_block_def_list(data~, offset=block_offset, version~)
      (
        entity_result.entities,
        block_result.block_defs,
        block_result.end_offset,
      )
    }
    None => (Array::new(), Array::new(), 0)
  }

  // Ver.7.00以上の場合、同梱画像をパース
  let embedded_images =
    if version >= 700 {
      parse_embedded_images(data~, offset=block_end_offset, version~)
    } else {
      Array::new()
    }

  // レイヤー名を設定
  let named_layer_groups = set_layer_names(layer_groups~)
  {
    version,
    memo,
    paper_size,
    write_layer_group,
    layer_groups: named_layer_groups,
    entities,
    block_defs,
    embedded_images,
    print_settings,
    sunpou_settings,
    metadata_settings: MetadataSettings::default(),
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
      let len_dword = reader.read_dword().reinterpret_as_int()
      // 過度に大きな値は保護
      if len_dword < 0 || len_dword > 1000000 {
        0
      } else {
        len_dword
      }
    }
  }

  // 長さが負または過度に大きい場合は空文字列を返す
  if length <= 0 || length > 1000000 {
    return ""
  }

  // 残りデータが不足している場合は可能な範囲で読み取る
  let actual_length = if reader.remaining() < length {
    reader.remaining()
  } else {
    length
  }
  let bytes = reader.read_bytes(n=actual_length)
  @encoding_sjis.shift_jis_to_utf8(data=bytes)
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
      let new_layer = { state: l.state, protect: l.protect, name: layer_name }
      layers.push(new_layer)
    }
    let new_group = {
      state: lg.state,
      write_layer: lg.write_layer,
      scale: lg.scale,
      protect: lg.protect,
      layers,
      name: group_name,
    }
    result.push(new_group)
  }
  result
}

///|
/// メタデータプレフィックスかどうかを判定する
fn is_metadata_text(content~ : String) -> Bool {
  content.has_prefix("Printer_") ||
  content.has_prefix("Draw_") ||
  content.has_prefix("View_")
}

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
pub struct EntityListResult {
  entities : Array[Entity]
  bytes_consumed : Int
}

///|
/// エンティティリストをパースする
pub fn parse_entity_list(
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
    let name_chars_array = Array::new()
    for i in 0..<name_bytes.length() {
      name_chars_array.push(name_bytes[i].to_char())
    }
    class_name = String::from_array(name_chars_array)

    // PIDを登録
    let pid = updated_next_pid
    if pid.reinterpret_as_int() < 65536 {
      updated_p2c[pid.reinterpret_as_int()] = class_name
    }
    updated_next_pid = pid + 1

    // 重要: 0xFFFFの場合、エンティティデータが直後に続く
    // returnせずにエンティティパースを継続する

  } else if class_id == 0x8000 {
    // Nullオブジェクト - エンティティデータなし
    return { entity: None, pid_to_class: updated_p2c, next_pid: next_pid + 1 }
  } else {
    // クラス参照: 0x8000 | class_pid
    let class_pid = class_id & 0x7FFF
    if class_pid < 65536 {
      let name = updated_p2c[class_pid]
      if name == "" {
        // 順方向参照: クラス定義がまだ見つかっていない
        // エンティティデータをスキップ（とりあえずCDataSenとして仮定）
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
  { entity, pid_to_class: updated_p2c, next_pid: updated_next_pid }
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

///|
/// ブロック定義リストパース結果
priv struct BlockDefListResult {
  block_defs : Array[BlockDef]
  end_offset : Int
}

///|
/// ブロック定義リストをパースする
fn parse_block_def_list(
  data~ : Bytes,
  offset~ : Int,
  version~ : UInt,
) -> BlockDefListResult {
  // offsetがデータ範囲外の場合は空配列を返す
  if offset >= data.length() {
    return { block_defs: Array::new(), end_offset: offset }
  }
  let block_data = Bytes::from_array(data.to_array()[offset:data.length()])
  let reader = Reader::new(data=block_data)
  let start_pos = reader.position()

  // データが4バイト未満の場合は空配列を返す
  if reader.remaining() < 4 {
    return { block_defs: Array::new(), end_offset: offset }
  }
  let count = reader.read_dword()

  // カウントが異常な値の場合は空配列を返す
  if count > 10000U {
    return { block_defs: Array::new(), end_offset: offset }
  }
  let block_defs = Array::new()

  // MFC CArchive PIDトラッキング（UInt16版）
  let mut class_map = Array::new()
  for _ in 0..<256 {
    class_map.push("")
  }
  let mut next_id : UInt16 = 1
  for _ in 0..<count.reinterpret_as_int() {
    // データが不足している場合はループを中断
    if reader.remaining() < 8 {
      break
    }
    let result = parse_block_def_with_tracking(
      reader~,
      version~,
      class_map~,
      next_id~,
    )
    match result.block_def {
      Some(bd) => block_defs.push(bd)
      None => {
        let _ = class_map

      }
    }
    class_map = result.class_map
    next_id = result.next_id
  }
  let end_pos = reader.position()
  { block_defs, end_offset: offset + (end_pos - start_pos) }
}

///|
/// ブロック定義パース結果
priv struct BlockDefResult {
  block_def : BlockDef?
  class_map : Array[String]
  next_id : UInt16
}

///|
/// トラッキング付きでブロック定義をパースする
fn parse_block_def_with_tracking(
  reader~ : Reader,
  version~ : UInt,
  class_map~ : Array[String],
  next_id~ : UInt16,
) -> BlockDefResult {
  let class_id = reader.read_word().to_int()
  let (updated_class_map, updated_next_id) = if class_id == 0xFFFF {
    // 新しいクラス定義
    let _schema = reader.read_word()
    let name_len = reader.read_word().to_int()
    let name_bytes = reader.read_bytes(n=name_len)

    // バイト列をASCII文字列として解釈
    let name_chars_array = Array::new()
    for i in 0..<name_bytes.length() {
      name_chars_array.push(name_bytes[i].to_char())
    }
    let class_name = String::from_array(name_chars_array)

    // PIDを登録
    let new_class_map = class_map
    let id_int = next_id.to_int()
    if id_int < 256 {
      new_class_map[id_int] = class_name
    }
    (new_class_map, next_id + 1)
  } else if class_id == 0x8000 {
    // Nullオブジェクト
    return { block_def: None, class_map, next_id: next_id + 1 }
  } else {
    // クラス参照: 0x8000 | class_pid
    let class_pid = class_id & 0x7FFF
    if class_pid < 256 {
      // クラス名を確認
      let _name = class_map[class_pid]
      (class_map, next_id)
    } else {
      return { block_def: None, class_map, next_id: next_id + 1 }
    }
  }
  let base = parse_entity_base(reader~, version~)
  let number = reader.read_dword()
  let ref_flag = reader.read_dword()
  let is_referenced = ref_flag != 0U

  // CTimeをスキップ (4バイト)
  let _ = reader.read_dword()
  let name = read_cstring(reader~)

  // 入れ子のエンティティをパース
  let nested_offset = reader.position()
  let nested_result = parse_entity_list(
    data=Bytes::from_array(reader.data),
    offset=nested_offset,
    version~,
  )
  {
    block_def: Some({
      base,
      number,
      is_referenced,
      name,
      entities: nested_result.entities,
    }),
    class_map: updated_class_map,
    next_id: updated_next_id,
  }
}

///|
/// 文字列内の ^@BM マーカーの位置を見つける
fn find_bm_marker(content~ : String) -> Int? {
  let chars = content.to_array()
  let len = chars.length()

  // "^@BM" (4文字: ^ @ B M) の位置を探す
  if len < 4 {
    return None
  }
  let mut i = 0
  while i < len - 3 {
    if chars[i] == '^' &&
      chars[i + 1] == '@' &&
      chars[i + 2] == 'B' &&
      chars[i + 3] == 'M' {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// @BM形式の文字列から画像情報をパースする
fn parse_image_from_bm_string(
  content~ : String,
  base~ : EntityBase,
  start_x~ : Double,
  start_y~ : Double,
  angle~ : Double,
  size_x~ : Double,
  size_y~ : Double,
) -> Image? {
  // ^@BM の位置を見つける
  let bm_offset = match find_bm_marker(content~) {
    Some(offset) => offset
    None => return None
  }
  // "^@BM" (4文字) を除去
  let chars = content.to_array()
  if chars.length() <= bm_offset + 4 {
    return None
  }
  let path_and_params = String::from_array(chars[bm_offset + 4:])
  // カンマで分割
  let parts = split_by_comma(path_and_params~)
  if parts.length() < 1 {
    return None
  }
  // 最初の部分がファイルパス
  let raw_path = parts[0]
  let image_path = normalize_image_path(raw_path~)
  // 幅と高さ: JWWはsize_x, size_yを使用（または後続パラメータ）
  let width = if parts.length() >= 2 {
    parse_double_or_default(parts[1], size_x)
  } else {
    size_x
  }
  let height = if parts.length() >= 3 {
    parse_double_or_default(parts[2], size_y)
  } else {
    size_y
  }
  Some({
    base,
    image_path,
    x: start_x,
    y: start_y,
    width,
    height,
    rotation: angle,
  })
}

///|
/// 文字列をカンマで分割する
fn split_by_comma(path_and_params~ : String) -> Array[String] {
  let result = Array::new()
  let mut current_array = Array::new()
  for c in path_and_params {
    if c == ',' {
      result.push(String::from_array(current_array))
      current_array = Array::new()
    } else {
      current_array.push(c)
    }
  }
  if current_array.length() > 0 {
    result.push(String::from_array(current_array))
  }
  result
}

///|
/// 画像パスを正規化する（%temp%などの環境変数プレフィックスを処理）
fn normalize_image_path(raw_path~ : String) -> String {
  let all_chars = raw_path.to_array()
  // %temp%プレフィックスを除去
  let chars = if raw_path.has_prefix("%temp%") && all_chars.length() > 6 {
    Array::from_iter(all_chars[6:].iter())
  } else {
    all_chars
  }
  // アンダースコアをスラッシュに変換（JWW特有のパス変換）
  // 例: C_Users_... -> C:/Users/...
  let normalized_array = Array::new()
  let mut prev_was_letter = false
  for c in chars {
    if c == '_' && prev_was_letter {
      normalized_array.push('/')
      prev_was_letter = false
    } else {
      normalized_array.push(c)
      prev_was_letter = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
    }
  }
  String::from_array(normalized_array)
}

///|
/// 文字列をDoubleにパースする（失敗時はデフォルト値を返す）
fn parse_double_or_default(s : String, default : Double) -> Double {
  @strconv.parse_double(s) catch {
    _ => default
  }
}

///|
/// 画像データのフォーマットをマジックバイトから検出する
fn detect_image_format(data~ : Bytes) -> ImageFormat {
  if data.length() < 4 {
    return ImageFormat::Unknown
  }

  let b0 = data[0].to_int()
  let b1 = data[1].to_int()
  let b2 = data[2].to_int()
  let b3 = data[3].to_int()

  // JPEG: FF D8 FF
  if b0 == 0xFF && b1 == 0xD8 && b2 == 0xFF {
    return ImageFormat::Jpeg
  }

  // PNG: 89 50 4E 47 (...PNG)
  if b0 == 0x89 && b1 == 0x50 && b2 == 0x4E && b3 == 0x47 {
    return ImageFormat::Png
  }

  // BMP: 42 4D (BM)
  if b0 == 0x42 && b1 == 0x4D {
    return ImageFormat::Bmp
  }

  // GIF: 47 49 46 38 (GIF8)
  if b0 == 0x47 && b1 == 0x49 && b2 == 0x46 && b3 == 0x38 {
    return ImageFormat::Gif
  }

  ImageFormat::Unknown
}

///|
/// 単一の同梱画像をパースする
fn parse_single_embedded_image(
  reader~ : Reader,
  index~ : UInt,
) -> EmbeddedImage? {
  // ファイルサイズを読み取り (DWORD = 4バイト)
  if reader.remaining() < 4 {
    return None
  }

  let file_size = reader.read_dword()

  // ファイルサイズの妥当性チェック
  // 0バイトまたは過度に大きい場合はエラー
  if file_size == 0U || file_size > 100_000_000U {
    // 100MB上限
    return None
  }

  let file_size_int = file_size.reinterpret_as_int()

  // 残りデータが不足している場合はNoneを返す
  if reader.remaining() < file_size_int {
    return None
  }

  // 画像データを読み取り
  let image_data = reader.read_bytes(n=file_size_int)

  // データが空の場合はNoneを返す
  if image_data.length() == 0 {
    return None
  }

  // 画像フォーマットを検出
  let format = detect_image_format(data=image_data)

  Some({
    index,
    file_size,
    data: image_data,
    format,
  })
}

///|
/// 同梱画像リストをパースする (Ver.7.00+)
fn parse_embedded_images(
  data~ : Bytes,
  offset~ : Int,
  version~ : UInt,
) -> Array[EmbeddedImage] {
  // Version 7.00未満では空配列を返す
  if version < 700 {
    return Array::new()
  }

  // offsetがデータ範囲外の場合は空配列を返す
  if offset >= data.length() {
    return Array::new()
  }

  let image_data = Bytes::from_array(data.to_array()[offset:data.length()])
  let reader = Reader::new(data=image_data)

  // データが4バイト未満の場合は空配列を返す
  if reader.remaining() < 4 {
    return Array::new()
  }

  // 画像数を読み取り
  let count = reader.read_dword()

  // カウントが異常な値の場合は空配列を返す（保護）
  // 同梱画像は通常数個程度
  if count > 1000U {
    return Array::new()
  }

  let embedded_images = Array::new()

  // 各画像をパース
  for i in 0..<count.reinterpret_as_int() {
    let result = parse_single_embedded_image(
      reader~,
      index=i.reinterpret_as_uint(),
    )
    match result {
      Some(img) => embedded_images.push(img)
      None => () // エラー時はスキップして継続
    }
  }

  embedded_images
}
