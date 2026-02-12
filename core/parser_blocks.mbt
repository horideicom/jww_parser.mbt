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
    let mut name_chars = ""
    for i in 0..<name_bytes.length() {
      name_chars = name_chars + name_bytes[i].to_char().to_string()
    }
    let class_name = name_chars

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
