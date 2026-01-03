///|
/// JWWファイルをパースしてドキュメントを取得
pub fn parse(data~ : Bytes) -> @core.Document {
  @core.parse(data~)
}

///|
/// JWWドキュメントをJSON文字列に変換
pub fn to_json_string(jww_doc : @core.Document) -> String {
  @core.document_to_json(jww_doc)
}
