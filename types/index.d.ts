/**
 * JWW Parser - TypeScript Type Definitions
 * @see https://github.com/fu2hito/jww_parser.mbt
 */

/**
 * Base attributes common to all entities
 */
export interface EntityBase {
  /** Curve group number (line style group) */
  group: number;
  /** Line style number */
  pen_style: number;
  /** Line color number (1-9 are basic colors, extended values are SXF colors) */
  pen_color: number;
  /** Line width (available in Ver.3.51+) */
  pen_width: number;
  /** Layer number (0-15) */
  layer: number;
  /** Layer group number (0-15) */
  layer_group: number;
  /** Various attribute flags */
  flag: number;
}

/**
 * Line entity (JWW class: CDataSen)
 */
export interface Line {
  base: EntityBase;
  start_x: number;
  start_y: number;
  end_x: number;
  end_y: number;
}

/**
 * Arc/Circle entity (JWW class: CDataEnko)
 */
export interface Arc {
  base: EntityBase;
  center_x: number;
  center_y: number;
  radius: number;
  /** Start angle in radians */
  start_angle: number;
  /** Arc angle in radians */
  arc_angle: number;
  /** Tilt angle in radians (for ellipses) */
  tilt_angle: number;
  /** 1.0 is a true circle, otherwise an ellipse */
  flatness: number;
  is_full_circle: boolean;
}

/**
 * Point entity (JWW class: CDataTen)
 */
export interface Point {
  base: EntityBase;
  x: number;
  y: number;
  is_temporary: boolean;
  code: number;
  angle: number;
  scale: number;
}

/**
 * Text entity (JWW class: CDataMoji)
 */
export interface Text {
  base: EntityBase;
  start_x: number;
  start_y: number;
  end_x: number;
  end_y: number;
  /** +10000 for italic, +20000 for bold */
  text_type: number;
  size_x: number;
  size_y: number;
  /** Character spacing */
  spacing: number;
  /** Rotation angle in degrees */
  angle: number;
  font_name: string;
  content: string;
}

/**
 * Solid/Fill entity (JWW class: CDataSolid)
 */
export interface Solid {
  base: EntityBase;
  point1_x: number;
  point1_y: number;
  point2_x: number;
  point2_y: number;
  point3_x: number;
  point3_y: number;
  point4_x: number;
  point4_y: number;
  /** Used when pen_color == 10 */
  color: number;
}

/**
 * Arc/Circle solid entity (CDataSolid with pen_style >= 101)
 */
export interface ArcSolid {
  base: EntityBase;
  /** Center X */
  center_x: number;
  /** Center Y */
  center_y: number;
  /** Outer radius */
  radius: number;
  /** 1.0 is a true circle, otherwise an ellipse */
  flatness: number;
  /** Tilt angle in radians */
  tilt_angle: number;
  /** Start angle in radians */
  start_angle: number;
  /** Arc angle in radians */
  arc_angle: number;
  /** Meaning depends on pen_style (type flag or inner radius) */
  solid_param: number;
  /** Used when pen_color == 10 */
  color: number;
}

/**
 * Block insertion entity (JWW class: CDataBlock)
 */
export interface Block {
  base: EntityBase;
  /** Insertion reference point X */
  ref_x: number;
  /** Insertion reference point Y */
  ref_y: number;
  scale_x: number;
  scale_y: number;
  /** Rotation in radians */
  rotation: number;
  /** Reference block definition number */
  def_number: number;
}

/**
 * Image entity (converted from CDataMoji ^@BM format)
 */
export interface Image {
  base: EntityBase;
  image_path: string;
  x: number;
  y: number;
  width: number;
  height: number;
  /** Rotation angle in degrees */
  rotation: number;
}

/**
 * Entity discriminated union
 * Use `type` property to discriminate between entity types
 */
export type Entity =
  | { type: "Line" | "CIRCLE" | "ARC"; value: Line & { __arcBrand?: never } }
  | { type: "Arc"; value: Arc }
  | { type: "Point"; value: Point }
  | { type: "Text"; value: Text }
  | { type: "Solid"; value: Solid }
  | { type: "ArcSolid"; value: ArcSolid }
  | { type: "Block"; value: Block }
  | { type: "Image"; value: Image };

/**
 * Image format type (detected from magic bytes)
 */
export enum ImageFormat {
  /** Undetected or unknown */
  Unknown = "Unknown",
  /** JPEG format (FF D8 FF) */
  Jpeg = "Jpeg",
  /** PNG format (89 50 4E 47) */
  Png = "Png",
  /** BMP format (42 4D) */
  Bmp = "Bmp",
  /** GIF format (47 49 46 38) */
  Gif = "Gif"
}

/**
 * Embedded image data (Ver.7.00+)
 */
export interface EmbeddedImage {
  /** Image index (0-based) */
  index: number;
  /** File size in bytes */
  file_size: number;
  /** Raw image binary data */
  data: Uint8Array;
  /** Image format detected from magic bytes */
  format: ImageFormat;
}

/**
 * Print settings
 */
export interface PrintSettings {
  /** Print output origin X */
  origin_x: number;
  /** Print output origin Y */
  origin_y: number;
  /** Print output scale */
  scale: number;
  /** Print 90-degree rotation / reference point position
   * 0: origin, 1: bottom-left, 2: bottom-right, 3: top-left, 4: top-right,
   * 5: center, 6: left, 7: top, 8: right, 9: bottom */
  rotation_setting: number;
}

/**
 * Sunpou (dimension) settings
 */
export interface SunpouSettings {
  /** m_lnSunpou1: character type, dimension decimal point, unit, etc. */
  sunpou1: number;
  /** m_lnSunpou2: dimension value coefficient, arrow size */
  sunpou2: number;
  /** m_lnSunpou3: character size, angle, arrow protrusion */
  sunpou3: number;
  /** m_lnSunpou4: correction flag */
  sunpou4: number;
  /** m_lnSunpou5: character style, angle unit */
  sunpou5: number;
  /** Reserved (one DWORD) */
  dummy: number;
  /** Maximum line width */
  max_line_width: number;
}

/**
 * Metadata settings (settings embedded in CDataMoji)
 */
export interface MetadataSettings {
  /** Printer paper size setting */
  printer_paper_size: string;
  /** BMP transparency setting */
  draw_bmp_touka: string;
  /** Direct2D display setting */
  view_direct2d: string;
  /** Printer BMP overall setting */
  printer_bmp_zentai: string;
  /** Printer orientation setting */
  printer_orientation: string;
  /** Printer D2D BMP setting */
  printer_d2d_bmp: string;
}

/**
 * Individual layer
 */
export interface Layer {
  /** Layer state: 0=hidden, 1=view-only, 2=editable, 3=write mode */
  state: number;
  protect: number;
  name: string;
}

/**
 * Layer group (contains 16 layers)
 */
export interface LayerGroup {
  /** Layer group state */
  state: number;
  /** Current write layer in group (0-15) */
  write_layer: number;
  /** Scale denominator (e.g., 100.0 for 1:100) */
  scale: number;
  /** Protection flag */
  protect: number;
  /** 16 layers in the group */
  layers: Layer[];
  /** Layer group name */
  name: string;
}

/**
 * Block definition
 */
export interface BlockDef {
  base: EntityBase;
  number: number;
  is_referenced: boolean;
  name: string;
  entities: Entity[];
}

/**
 * JWW document
 */
export interface Document {
  /** JWW file format version (e.g., 351 for Ver.3.51, 420 for Ver.4.20, 700 for Ver.7.00+) */
  version: number;
  /** File memo/description */
  memo: string;
  /** Paper size: 0-4 for A0-A4, 8 for 2A, 9 for 3A, etc. */
  paper_size: number;
  /** Current write layer group (0-15) */
  write_layer_group: number;
  /** 16 layer groups */
  layer_groups: LayerGroup[];
  /** Drawing entities */
  entities: Entity[];
  /** Block definitions */
  block_defs: BlockDef[];
  /** Embedded images (Ver.7.00+) */
  embedded_images: EmbeddedImage[];
  /** Print settings */
  print_settings: PrintSettings;
  /** Sunpou (dimension) settings */
  sunpou_settings: SunpouSettings;
  /** Metadata settings (extracted from CDataMoji) */
  metadata_settings: MetadataSettings;
}

/**
 * Parse JWW binary data into a Document object
 * @param data - Binary data as Uint8Array
 * @returns Parsed JWW document
 */
export function parse(data: Uint8Array): Document;

/**
 * Convert a JWW Document to JSON string
 * @param jww_doc - JWW document object
 * @returns JSON string representation
 */
export function to_json_string(jww_doc: Document): string;
