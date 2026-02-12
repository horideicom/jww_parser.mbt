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
  { origin_x, origin_y, scale, rotation_setting }
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
  { sunpou1, sunpou2, sunpou3, sunpou4, sunpou5, dummy, max_line_width }
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
