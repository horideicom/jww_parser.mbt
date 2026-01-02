///|
/// JWWファイル型定義

///|
/// 全エンティティに共通する属性
pub struct EntityBase {
  /// 曲線属性番号 (線種グループ)
  group : UInt
  /// 線種番号
  pen_style : Byte
  /// 線色番号 (1-9は基本色、拡張値はSXF色)
  pen_color : UInt16
  /// 線幅 (Ver.3.51以降で利用可能)
  pen_width : UInt16
  /// レイヤ番号 (0-15)
  layer : UInt16
  /// レイヤグループ番号 (0-15)
  layer_group : UInt16
  /// 各種属性フラグ
  flag : UInt16
} derive(Show, Eq)

///|
/// 直線エンティティ (JWWクラス: CDataSen)
pub struct Line {
  base : EntityBase
  start_x : Double
  start_y : Double
  end_x : Double
  end_y : Double
} derive(Show, Eq)

///|
/// 円弧/円エンティティ (JWWクラス: CDataEnko)
pub struct Arc {
  base : EntityBase
  center_x : Double
  center_y : Double
  radius : Double
  start_angle : Double // ラジアン
  arc_angle : Double // ラジアン
  tilt_angle : Double // ラジアン（楕円の場合）
  flatness : Double // 1.0は真円、それ以外は楕円
  is_full_circle : Bool
} derive(Show, Eq)

///|
/// 点エンティティ (JWWクラス: CDataTen)
pub struct Point {
  base : EntityBase
  x : Double
  y : Double
  is_temporary : Bool
  code : UInt
  angle : Double
  scale : Double
} derive(Show, Eq)

///|
/// 文字エンティティ (JWWクラス: CDataMoji)
pub struct Text {
  base : EntityBase
  start_x : Double
  start_y : Double
  end_x : Double
  end_y : Double
  text_type : UInt // +10000でイタリック、+20000で太字
  size_x : Double
  size_y : Double
  spacing : Double // 文字間隔
  angle : Double // 回転角度（度）
  font_name : String
  content : String
} derive(Show, Eq)

///|
/// 塗りつぶしエンティティ (JWWクラス: CDataSolid)
pub struct Solid {
  base : EntityBase
  point1_x : Double
  point1_y : Double
  point2_x : Double
  point2_y : Double
  point3_x : Double
  point3_y : Double
  point4_x : Double
  point4_y : Double
  color : UInt // pen_color == 10の時使用
} derive(Show, Eq)

///|
/// ブロック挿入エンティティ (JWWクラス: CDataBlock)
pub struct Block {
  base : EntityBase
  ref_x : Double // 挿入基準点X
  ref_y : Double // 挿入基準点Y
  scale_x : Double
  scale_y : Double
  rotation : Double // ラジアン
  def_number : UInt // 参照先ブロック定義番号
} derive(Show, Eq)

///|
/// 画像エンティティ (CDataMojiの^@BM形式から変換)
pub struct Image {
  base : EntityBase
  image_path : String // 画像ファイルパス
  x : Double // 挿入位置X
  y : Double // 挿入位置Y
  width : Double // 幅
  height : Double // 高さ
  rotation : Double // 回転角度（度）
} derive(Show, Eq)

///|
/// 画像フォーマット種別（マジックバイトから検出）
pub enum ImageFormat {
  /// 未検出または不明
  Unknown
  /// JPEG形式 (FF D8 FF)
  Jpeg
  /// PNG形式 (89 50 4E 47)
  Png
  /// BMP形式 (42 4D)
  Bmp
  /// GIF形式 (47 49 46 38)
  Gif
} derive(Show, Eq)

///|
/// 同梱画像データ (Ver.7.00+)
pub struct EmbeddedImage {
  /// 画像のインデックス（0始まり）
  index : UInt
  /// ファイルサイズ（バイト）
  file_size : UInt
  /// 画像データ（生バイナリ）
  data : Bytes
  /// 画像フォーマット（マジックバイトから検出）
  format : ImageFormat
} derive(Show, Eq)

///|
/// 印刷設定情報
pub struct PrintSettings {
  /// 印刷出力範囲の基点X
  origin_x : Double
  /// 印刷出力範囲の基点Y
  origin_y : Double
  /// 印刷出力倍率
  scale : Double
  /// 印刷90度回転・基準点位置
  /// 0:原点 1:左下 2:右下 3:左上 4:右上 5:中心 6:左 7:上 8:右 9:下
  rotation_setting : UInt
} derive(Show, Eq)

///|
/// 日光設定（寸法設定）
pub struct SunpouSettings {
  /// m_lnSunpou1: 文字種・寸法小数点・単位等
  sunpou1 : UInt
  /// m_lnSunpou2: 寸法値係数・矢印の大きさ
  sunpou2 : UInt
  /// m_lnSunpou3: 文字サイズ・角度・矢印突き出し
  sunpou3 : UInt
  /// m_lnSunpou4: 補正フラグ
  sunpou4 : UInt
  /// m_lnSunpou5: 文字スタイル・角度単位
  sunpou5 : UInt
  /// 予備 (1個のDWORD)
  dummy : UInt
  /// 線の最大幅
  max_line_width : UInt
} derive(Show, Eq)

///|
/// メタデータ設定（CDataMojiに埋め込まれた設定情報）
pub struct MetadataSettings {
  /// プリンター用紙サイズ設定
  printer_paper_size : String
  /// BMP透過設定
  draw_bmp_touka : String
  /// Direct2D表示設定
  view_direct2d : String
  /// プリンターBMP全体設定
  printer_bmp_zentai : String
  /// プリンター方向設定
  printer_orientation : String
  /// プリンターD2dBMP設定
  printer_d2d_bmp : String
} derive(Show, Eq)

///|
/// エンティティ種別
pub enum Entity {
  Line(Line)
  Arc(Arc)
  Point(Point)
  Text(Text)
  Solid(Solid)
  Block(Block)
  Image(Image)
} derive(Show, Eq)

///|
/// 個別レイヤ
pub struct Layer {
  /// レイヤの状態: 0=非表示, 1=表示のみ, 2=編集可能, 3=書込モード
  state : UInt
  protect : UInt
  name : String
} derive(Show, Eq)

///|
/// レイヤグループ（16個のレイヤを含む）
pub struct LayerGroup {
  /// レイヤグループの状態
  state : UInt
  /// グループ内の現在の書き込みレイヤ (0-15)
  write_layer : UInt
  /// スケール分母（例: 100.0で1:100）
  scale : Double
  /// 保護フラグ
  protect : UInt
  /// 16個のレイヤ
  layers : Array[Layer]
  /// レイヤグループ名
  name : String
} derive(Show, Eq)

///|
/// ブロック定義
pub struct BlockDef {
  base : EntityBase
  number : UInt
  is_referenced : Bool
  name : String
  entities : Array[Entity]
} derive(Show, Eq)

///|
/// JWWドキュメント全体
pub struct Document {
  /// JWWファイルフォーマットバージョン (例: 351 for Ver.3.51, 420 for Ver.4.20)
  version : UInt
  /// ファイルメモ/説明
  memo : String
  /// 用紙サイズ: 0-4でA0-A4、8で2A、9で3Aなど
  paper_size : UInt
  /// 現在の書き込みレイヤグループ (0-15)
  write_layer_group : UInt
  /// 16個のレイヤグループ
  layer_groups : Array[LayerGroup]
  /// 図面エンティティ
  entities : Array[Entity]
  /// ブロック定義
  block_defs : Array[BlockDef]
  /// 同梱画像 (Ver.7.00+)
  embedded_images : Array[EmbeddedImage]
  /// 印刷設定
  print_settings : PrintSettings
  /// 日光設定（寸法設定）
  sunpou_settings : SunpouSettings
  /// メタデータ設定（CDataMojiから抽出）
  metadata_settings : MetadataSettings
} derive(Show, Eq)

///|
/// EntityBaseのデフォルト値
pub fn EntityBase::default() -> EntityBase {
  {
    group: 0,
    pen_style: 0,
    pen_color: 1,
    pen_width: 0,
    layer: 0,
    layer_group: 0,
    flag: 0,
  }
}

///|
/// Layerのデフォルト値
pub fn Layer::default() -> Layer {
  { state: 2, protect: 0, name: "" }
}

///|
/// LayerGroupのデフォルト値
pub fn LayerGroup::default() -> LayerGroup {
  // 16個のデフォルトレイヤを作成
  let layers = Array::new()
  for _ in 0..<16 {
    layers.push(Layer::default())
  }
  { state: 2, write_layer: 0, scale: 1.0, protect: 0, layers, name: "" }
}

///|
/// MetadataSettingsのデフォルト値
pub fn MetadataSettings::default() -> MetadataSettings {
  {
    printer_paper_size: "",
    draw_bmp_touka: "",
    view_direct2d: "",
    printer_bmp_zentai: "",
    printer_orientation: "",
    printer_d2d_bmp: "",
  }
}

///|
/// SunpouSettingsのデフォルト値
pub fn SunpouSettings::default() -> SunpouSettings {
  {
    sunpou1: 0,
    sunpou2: 0,
    sunpou3: 0,
    sunpou4: 0,
    sunpou5: 0,
    dummy: 0,
    max_line_width: 0,
  }
}

///|
/// Documentのデフォルト値
pub fn Document::default() -> Document {
  // 16個のデフォルトレイヤグループを作成
  let layer_groups = Array::new()
  for _ in 0..<16 {
    layer_groups.push(LayerGroup::default())
  }
  {
    version: 0,
    memo: "",
    paper_size: 0,
    write_layer_group: 0,
    layer_groups,
    entities: Array::new(),
    block_defs: Array::new(),
    embedded_images: Array::new(),
    print_settings: {
      origin_x: 0.0,
      origin_y: 0.0,
      scale: 1.0,
      rotation_setting: 0,
    },
    sunpou_settings: SunpouSettings::default(),
    metadata_settings: MetadataSettings::default(),
  }
}

///|
/// エンティティの基本属性を取得
pub fn Entity::base(self : Entity) -> EntityBase {
  match self {
    Line(l) => l.base
    Arc(a) => a.base
    Point(p) => p.base
    Text(t) => t.base
    Solid(s) => s.base
    Block(b) => b.base
    Image(i) => i.base
  }
}

///|
/// エンティティタイプ名を取得
pub fn Entity::type_name(self : Entity) -> String {
  match self {
    Line(_) => "LINE"
    Arc(a) => if a.is_full_circle { "CIRCLE" } else { "ARC" }
    Point(_) => "POINT"
    Text(_) => "TEXT"
    Solid(_) => "SOLID"
    Block(_) => "BLOCK"
    Image(_) => "IMAGE"
  }
}
