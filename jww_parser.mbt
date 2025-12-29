///|
/// JWWファイルをパースしてドキュメントを取得
pub fn parse(data~ : Bytes) -> @core.Document {
  @core.parse(data=data)
}

///|
/// JWWドキュメントをDXFドキュメントに変換
pub fn to_dxf_document(jww_doc~ : @core.Document) -> @dxf.DxfDocument {
  @dxf.convert_document(jww_doc=jww_doc)
}

///|
/// JWWドキュメントをDXF文字列に変換
pub fn to_dxf_string(jww_doc~ : @core.Document) -> String {
  let dxf_doc = @dxf.convert_document(jww_doc=jww_doc)
  @dxf.to_string(doc=dxf_doc)
}

///|
/// JWWバイナリデータを直接DXF文字列に変換
pub fn jww_to_dxf(data~ : Bytes) -> String {
  let jww_doc = @core.parse(data=data)
  let dxf_doc = @dxf.convert_document(jww_doc=jww_doc)
  @dxf.to_string(doc=dxf_doc)
}

///|
/// JWWドキュメントをJSON文字列に変換
pub fn to_json_string(jww_doc~ : @core.Document) -> String {
  "{\"version\":" + jww_doc.version.to_string() + "}"
}
