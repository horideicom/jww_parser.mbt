///|
/// DXF文字列出力

///|
/// DXFドキュメントを文字列に変換する
pub fn to_string(doc~ : DxfDocument) -> String {
  let mut output = ""

  // ヘッダーセクション
  output = output + "0\nSECTION\n2\nHEADER\n"
  output = output + "9\n$ACADVER\n1\nAC1015\n"
  output = output + "9\n$INSBASE\n10\n0.0\n20\n0.0\n30\n0.0\n"
  output = output + "9\n$EXTMIN\n10\n0.0\n20\n0.0\n30\n0.0\n"
  output = output + "9\n$EXTMAX\n10\n1000.0\n20\n1000.0\n30\n0.0\n"
  output = output + "9\n$LIMMIN\n10\n0.0\n20\n0.0\n"
  output = output + "9\n$LIMMAX\n10\n1000.0\n20\n1000.0\n"
  output = output + "0\nENDSEC\n"

  // テーブルセクション
  output = output + "0\nSECTION\n2\nTABLES\n"

  // LTYPEテーブル
  output = output + ltype_table()

  // LAYERテーブル
  output = output + layer_table(doc~)

  // STYLEテーブル
  output = output + style_table()
  output = output + "0\nENDSEC\n"

  // ブロックセクション
  if doc.blocks.length() > 0 {
    output = output + "0\nSECTION\n2\nBLOCKS\n"
    for block in doc.blocks {
      output = output + write_block(block~)
    }
    output = output + "0\nENDSEC\n"
  }

  // エンティティセクション
  output = output + "0\nSECTION\n2\nENTITIES\n"
  for entity in doc.entities {
    output = output + write_entity(entity~)
  }
  output = output + "0\nENDSEC\n"

  // ファイル終了
  output = output + "0\nEOF\n"
  output
}

///|
/// LTYPEテーブルを生成（11種類の線種）
fn ltype_table() -> String {
  let mut output = ""
  output = output + "0\nTABLE\n"
  output = output + "2\nLTYPE\n"
  output = output + "70\n11\n"

  // 線種定義（JWW対応）
  let ltypes = [
    ("CONTINUOUS", "Solid line", ""),
    ("DASHED", "Dashed", ""),
    ("DOTTED", "Dotted", ""),
    ("DASHDOT", "Dash dot", ""),
    ("DOT2", "Dot (small)", ""),
    ("DASHDOT2", "Dash dot (small)", ""),
    ("DASHDOTDOT", "Dash dot dot", ""),
    ("DIVIDE", "Divide", ""),
    ("CENTER", "Center", ""),
    ("BORDER", "Border", ""),
    ("HIDDEN", "Hidden", ""),
  ]
  for lt in ltypes {
    let (name, desc, _) = lt
    output = output + "0\nLTYPE\n"
    output = output + "2\n" + name + "\n"
    output = output + "70\n0\n"
    output = output + "3\n" + desc + "\n"
    output = output + "72\n65\n"
    output = output + "73\n0\n"
    output = output + "40\n0.0\n"
  }
  output = output + "0\nENDTAB\n"
  output
}

///|
/// STYLEテーブルを生成
fn style_table() -> String {
  let mut output = ""
  output = output + "0\nTABLE\n"
  output = output + "2\nSTYLE\n"
  output = output + "70\n1\n"

  // 標準スタイル
  output = output + "0\nSTYLE\n"
  output = output + "2\nSTANDARD\n"
  output = output + "70\n0\n"
  output = output + "40\n0.0\n"
  output = output + "41\n1.0\n"
  output = output + "50\n0.0\n"
  output = output + "71\n0\n"
  output = output + "42\n0.2\n"
  output = output + "3\ntxt\n"
  output = output + "4\n\n"
  output = output + "0\nENDTAB\n"
  output
}

///|
/// LAYERテーブルを生成
fn layer_table(doc~ : DxfDocument) -> String {
  let mut output = ""
  output = output + "0\nTABLE\n2\nLAYER\n70\n"
  output = output + (doc.layers.length() + 1).to_string()
  output = output + "\n"

  // 必須レイヤー "0" (DXF仕様で必須)
  output = output + "0\nLAYER\n2\n0\n70\n0\n62\n7\n6\nCONTINUOUS\n"
  for layer in doc.layers {
    output = output + "0\nLAYER\n2\n"
    output = output + layer.name
    output = output + "\n70\n0\n62\n"
    output = output + layer.color.to_string()
    output = output + "\n6\n"
    output = output + layer.line_type
    if layer.frozen {
      output = output + "\n70\n1"
    }
    if layer.locked {
      output = output + "\n70\n4"
    }
    output = output + "\n"
  }
  output = output + "0\nENDTAB\n"
  output
}

///|
/// ブロックをDXF形式で出力
fn write_block(block~ : DxfBlock) -> String {
  let mut output = ""
  output = output + "0\nBLOCK\n8\n0\n2\n"
  output = output + block.name
  output = output + "\n70\n0\n10\n"
  output = output + block.base_x.to_string()
  output = output + "\n20\n"
  output = output + block.base_y.to_string()
  output = output + "\n"
  for entity in block.entities {
    output = output + write_entity(entity~)
  }
  output = output + "0\nENDBLK\n"
  output
}

///|
/// エンティティをDXF形式で出力する
fn write_entity(entity~ : DxfEntity) -> String {
  match entity {
    DxfEntity::Line(line) => {
      let mut output = "0\nLINE\n8\n"
      output = output + line.layer
      output = output + "\n62\n"
      output = output + line.color.to_string()
      output = output + "\n6\n"
      output = output + line.line_type
      output = output + "\n10\n"
      output = output + line.x1.to_string()
      output = output + "\n20\n"
      output = output + line.y1.to_string()
      output = output + "\n11\n"
      output = output + line.x2.to_string()
      output = output + "\n21\n"
      output = output + line.y2.to_string()
      output = output + "\n"
      output
    }
    DxfEntity::Circle(circle) => {
      let mut output = "0\nCIRCLE\n8\n"
      output = output + circle.layer
      output = output + "\n62\n"
      output = output + circle.color.to_string()
      output = output + "\n6\n"
      output = output + circle.line_type
      output = output + "\n10\n"
      output = output + circle.center_x.to_string()
      output = output + "\n20\n"
      output = output + circle.center_y.to_string()
      output = output + "\n40\n"
      output = output + circle.radius.to_string()
      output = output + "\n"
      output
    }
    DxfEntity::Arc(arc) => {
      let mut output = "0\nARC\n8\n"
      output = output + arc.layer
      output = output + "\n62\n"
      output = output + arc.color.to_string()
      output = output + "\n6\n"
      output = output + arc.line_type
      output = output + "\n10\n"
      output = output + arc.center_x.to_string()
      output = output + "\n20\n"
      output = output + arc.center_y.to_string()
      output = output + "\n40\n"
      output = output + arc.radius.to_string()
      output = output + "\n50\n"
      output = output + arc.start_angle.to_string()
      output = output + "\n51\n"
      output = output + arc.end_angle.to_string()
      output = output + "\n"
      output
    }
    DxfEntity::Ellipse(ellipse) => {
      let mut output = "0\nELLIPSE\n8\n"
      output = output + ellipse.layer
      output = output + "\n62\n"
      output = output + ellipse.color.to_string()
      output = output + "\n6\n"
      output = output + ellipse.line_type
      output = output + "\n10\n"
      output = output + ellipse.center_x.to_string()
      output = output + "\n20\n"
      output = output + ellipse.center_y.to_string()
      output = output + "\n11\n"
      output = output + ellipse.major_axis_x.to_string()
      output = output + "\n21\n"
      output = output + ellipse.major_axis_y.to_string()
      output = output + "\n40\n"
      output = output + ellipse.minor_ratio.to_string()
      output = output + "\n41\n"
      output = output + ellipse.start_param.to_string()
      output = output + "\n42\n"
      output = output + ellipse.end_param.to_string()
      output = output + "\n"
      output
    }
    DxfEntity::Point(point) => {
      let mut output = "0\nPOINT\n8\n"
      output = output + point.layer
      output = output + "\n62\n"
      output = output + point.color.to_string()
      output = output + "\n6\n"
      output = output + point.line_type
      output = output + "\n10\n"
      output = output + point.x.to_string()
      output = output + "\n20\n"
      output = output + point.y.to_string()
      output = output + "\n"
      output
    }
    DxfEntity::Text(text) => {
      let mut output = "0\nTEXT\n8\n"
      output = output + text.layer
      output = output + "\n62\n"
      output = output + text.color.to_string()
      output = output + "\n6\n"
      output = output + text.line_type
      output = output + "\n10\n"
      output = output + text.x.to_string()
      output = output + "\n20\n"
      output = output + text.y.to_string()
      output = output + "\n40\n"
      output = output + text.height.to_string()
      output = output + "\n50\n"
      output = output + text.rotation.to_string()
      output = output + "\n1\n"
      output = output + text.content
      output = output + "\n7\n"
      output = output + text.style
      output = output + "\n"
      output
    }
    DxfEntity::Solid(solid) => {
      let mut output = "0\nSOLID\n8\n"
      output = output + solid.layer
      output = output + "\n62\n"
      output = output + solid.color.to_string()
      output = output + "\n6\n"
      output = output + solid.line_type
      output = output + "\n10\n"
      output = output + solid.x1.to_string()
      output = output + "\n20\n"
      output = output + solid.y1.to_string()
      output = output + "\n11\n"
      output = output + solid.x2.to_string()
      output = output + "\n21\n"
      output = output + solid.y2.to_string()
      output = output + "\n12\n"
      output = output + solid.x3.to_string()
      output = output + "\n22\n"
      output = output + solid.y3.to_string()
      output = output + "\n13\n"
      output = output + solid.x4.to_string()
      output = output + "\n23\n"
      output = output + solid.y4.to_string()
      output = output + "\n"
      output
    }
    DxfEntity::Insert(insert) => {
      let mut output = "0\nINSERT\n8\n"
      output = output + insert.layer
      output = output + "\n62\n"
      output = output + insert.color.to_string()
      output = output + "\n6\n"
      output = output + insert.line_type
      output = output + "\n2\n"
      output = output + insert.block_name
      output = output + "\n10\n"
      output = output + insert.x.to_string()
      output = output + "\n20\n"
      output = output + insert.y.to_string()
      output = output + "\n41\n"
      output = output + insert.scale_x.to_string()
      output = output + "\n42\n"
      output = output + insert.scale_y.to_string()
      output = output + "\n50\n"
      output = output + insert.rotation.to_string()
      output = output + "\n"
      output
    }
  }
}
