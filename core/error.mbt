///|
/// JWWファイルパース時のエラー型
pub enum ParseError {
  /// 無効なシグネチャ（"JwwData."でない）
  InvalidSignature
  /// サポートされていないバージョン
  UnsupportedVersion(UInt)
  /// 不明なクラスPID
  UnknownClassPid(UInt)
  /// 不明なエンティティクラス
  UnknownEntityClass(String)
  /// データの予期せぬ終了
  UnexpectedEof
  /// I/Oエラー
  IoError(String)
  /// その他のエラー
  Other(String)
}

///|
/// エラーメッセージを取得
pub fn ParseError::to_string(self : ParseError) -> String {
  match self {
    InvalidSignature => "Invalid JWW signature"
    UnsupportedVersion(v) => "Unsupported version: " + v.to_string()
    UnknownClassPid(pid) => "Unknown class PID: " + pid.to_string()
    UnknownEntityClass(name) => "Unknown entity class: " + name
    UnexpectedEof => "Unexpected end of data"
    IoError(msg) => msg
    Other(msg) => msg
  }
}
