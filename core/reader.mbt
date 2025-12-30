///|
/// バイナリデータリーダー
/// カーソル位置を追跡しながらリトルエンディアンで読み込む
pub struct Reader {
  data : Array[Byte]
  mut pos : Int
}

///|
/// 新しいリーダーを作成
pub fn Reader::new(data~ : Bytes) -> Reader {
  { data: data.to_array(), pos: 0 }
}

///|
/// 現在の位置を取得
pub fn Reader::position(self : Reader) -> Int {
  self.pos
}

///|
/// データの長さを取得
pub fn Reader::length(self : Reader) -> Int {
  self.data.length()
}

///|
/// まだデータが残っているか
pub fn Reader::has_remaining(self : Reader) -> Bool {
  self.pos < self.data.length()
}

///|
/// 残りのバイト数を取得
pub fn Reader::remaining(self : Reader) -> Int {
  self.data.length() - self.pos
}

///|
/// 1バイト読み込んで位置を進める
pub fn Reader::read_byte(self : Reader) -> Byte {
  let b = self.data[self.pos]
  self.pos = self.pos + 1
  b
}

///|
/// 2バイト読み込む（リトルエンディアン、UInt16）
pub fn Reader::read_word(self : Reader) -> UInt16 {
  let b0 = self.read_byte().to_uint16()
  let b1 = self.read_byte().to_uint16()
  b0 | (b1 << 8)
}

///|
/// 4バイト読み込む（リトルエンディアン、UInt32）
pub fn Reader::read_dword(self : Reader) -> UInt {
  let b0 = self.read_byte().to_uint()
  let b1 = self.read_byte().to_uint()
  let b2 = self.read_byte().to_uint()
  let b3 = self.read_byte().to_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
/// 8バイト読み込んでUInt64として解釈
pub fn Reader::read_uint64(self : Reader) -> UInt64 {
  let b0 = self.read_byte().to_uint64()
  let b1 = self.read_byte().to_uint64()
  let b2 = self.read_byte().to_uint64()
  let b3 = self.read_byte().to_uint64()
  let b4 = self.read_byte().to_uint64()
  let b5 = self.read_byte().to_uint64()
  let b6 = self.read_byte().to_uint64()
  let b7 = self.read_byte().to_uint64()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24) | (b4 << 32) | (b5 << 40) | (b6 << 48) | (b7 << 56)
}

///|
/// IEEE 754 double (8バイト) を読み込む
pub fn Reader::read_double(self : Reader) -> Double {
  let bits = self.read_uint64()
  UInt64::to_double(bits)
}

///|
/// nバイトスキップする
pub fn Reader::skip(self : Reader, n~ : Int) -> Unit {
  self.pos = self.pos + n
}

///|
/// nバイト読み込む
/// データが不足している場合は空のBytesを返す
pub fn Reader::read_bytes(self : Reader, n~ : Int) -> Bytes {
  if self.remaining() < n {
    return Bytes::from_array([])
  }
  let start = self.pos
  let end = self.pos + n
  self.pos = end
  Bytes::from_array(self.data[start:end])
}
