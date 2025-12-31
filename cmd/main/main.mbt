///|
/// JWWファイルをDXF文字列に変換
pub fn jww_to_dxf(data : Bytes) -> String {
  @lib.jww_to_dxf(data~)
}

///|
/// JWWファイルをJSON文字列にパース
pub fn jww_to_json(data : Bytes) -> String {
  let doc = @lib.parse(data~)
  @lib.to_json_string(jww_doc=doc)
}

///|
/// バージョン情報
pub fn version() -> String {
  "0.1.0-moonbit"
}

///|
/// テスト用のmain関数
fn main {
  println("jww-parser-moonbit version: " + version())
}
