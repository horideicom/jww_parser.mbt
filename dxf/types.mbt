///|
/// DXF型定義

///|
/// DXFレイヤ
pub struct DxfLayer {
  name : String
  color : Int
  line_type : String
  frozen : Bool
  locked : Bool
}

///|
/// DXF直線
pub struct DxfLine {
  layer : String
  color : Int
  line_type : String
  x1 : Double
  y1 : Double
  x2 : Double
  y2 : Double
}

///|
/// DXF円
pub struct DxfCircle {
  layer : String
  color : Int
  line_type : String
  center_x : Double
  center_y : Double
  radius : Double
}

///|
/// DXF円弧
pub struct DxfArc {
  layer : String
  color : Int
  line_type : String
  center_x : Double
  center_y : Double
  radius : Double
  start_angle : Double  // 度
  end_angle : Double    // 度
}

///|
/// DXF楕円
pub struct DxfEllipse {
  layer : String
  color : Int
  line_type : String
  center_x : Double
  center_y : Double
  major_axis_x : Double
  major_axis_y : Double
  minor_ratio : Double
  start_param : Double
  end_param : Double
}

///|
/// DXF点
pub struct DxfPoint {
  layer : String
  color : Int
  line_type : String
  x : Double
  y : Double
}

///|
/// DXF文字
pub struct DxfText {
  layer : String
  color : Int
  line_type : String
  x : Double
  y : Double
  height : Double
  rotation : Double  // 度
  content : String
  style : String
}

///|
/// DXFソリッド（塗りつぶし）
pub struct DxfSolid {
  layer : String
  color : Int
  line_type : String
  x1 : Double
  y1 : Double
  x2 : Double
  y2 : Double
  x3 : Double
  y3 : Double
  x4 : Double
  y4 : Double
}

///|
/// DXFブロック挿入
pub struct DxfInsert {
  layer : String
  color : Int
  line_type : String
  block_name : String
  x : Double
  y : Double
  scale_x : Double
  scale_y : Double
  rotation : Double  // 度
}

///|
/// DXFエンティティ
pub enum DxfEntity {
  Line(DxfLine)
  Circle(DxfCircle)
  Arc(DxfArc)
  Ellipse(DxfEllipse)
  Point(DxfPoint)
  Text(DxfText)
  Solid(DxfSolid)
  Insert(DxfInsert)
}

///|
/// DXFブロック定義
pub struct DxfBlock {
  name : String
  base_x : Double
  base_y : Double
  entities : Array[DxfEntity]
}

///|
/// DXFドキュメント
pub struct DxfDocument {
  layers : Array[DxfLayer]
  entities : Array[DxfEntity]
  blocks : Array[DxfBlock]
}

///|
/// DXFドキュメントのデフォルト値
pub fn DxfDocument::default() -> DxfDocument {
  {
    layers: Array::new(),
    entities: Array::new(),
    blocks: Array::new()
  }
}

///|
/// DXFエンティティのレイヤ名を取得
pub fn DxfEntity::layer(self : DxfEntity) -> String {
  match self {
    Line(e) => e.layer
    Circle(e) => e.layer
    Arc(e) => e.layer
    Ellipse(e) => e.layer
    Point(e) => e.layer
    Text(e) => e.layer
    Solid(e) => e.layer
    Insert(e) => e.layer
  }
}

///|
/// DXFエンティティの色を取得
pub fn DxfEntity::color(self : DxfEntity) -> Int {
  match self {
    Line(e) => e.color
    Circle(e) => e.color
    Arc(e) => e.color
    Ellipse(e) => e.color
    Point(e) => e.color
    Text(e) => e.color
    Solid(e) => e.color
    Insert(e) => e.color
  }
}
