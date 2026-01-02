///|
/// JWWファイルをパースしてドキュメントを取得
pub fn parse(data~ : Bytes) -> @core.Document {
  @core.parse(data~)
}

///|
/// JWWドキュメントをJSON文字列に変換
pub fn to_json_string(jww_doc~ : @core.Document) -> String {
  "{\"version\":" + jww_doc.version.to_string() + "}"
}
