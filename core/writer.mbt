///|
/// バイナリデータライター
/// リトルエンディアンで書き込む
pub struct Writer {
  mut buffer : Array[Byte]
}

///|
/// 新しいライターを作成
pub fn Writer::new() -> Writer {
  { buffer: Array::new() }
}

///|
/// 現在のバッファサイズを取得
pub fn Writer::length(self : Writer) -> Int {
  self.buffer.length()
}

///|
/// 1バイト書き込む
pub fn Writer::write_byte(self : Writer, b~ : Byte) -> Unit {
  self.buffer.push(b)
}

///|
/// 2バイト書き込む（リトルエンディアン、UInt16）
pub fn Writer::write_word(self : Writer, w~ : UInt16) -> Unit {
  let lo = (w.to_uint() & 0xFFU).to_byte()
  let hi = ((w.to_uint() >> 8) & 0xFFU).to_byte()
  self.buffer.push(lo)
  self.buffer.push(hi)
}

///|
/// 4バイト書き込む（リトルエンディアン、UInt32）
pub fn Writer::write_dword(self : Writer, d~ : UInt) -> Unit {
  self.buffer.push((d & 0xFFU).to_byte())
  self.buffer.push(((d >> 8) & 0xFFU).to_byte())
  self.buffer.push(((d >> 16) & 0xFFU).to_byte())
  self.buffer.push(((d >> 24) & 0xFFU).to_byte())
}

///|
/// IEEE 754 double (8バイト) を書き込む
pub fn Writer::write_double(self : Writer, d~ : Double) -> Unit {
  let bits = Double::reinterpret_as_uint64(d)
  self.buffer.push((bits & 0xFFUL).to_byte())
  self.buffer.push(((bits >> 8) & 0xFFUL).to_byte())
  self.buffer.push(((bits >> 16) & 0xFFUL).to_byte())
  self.buffer.push(((bits >> 24) & 0xFFUL).to_byte())
  self.buffer.push(((bits >> 32) & 0xFFUL).to_byte())
  self.buffer.push(((bits >> 40) & 0xFFUL).to_byte())
  self.buffer.push(((bits >> 48) & 0xFFUL).to_byte())
  self.buffer.push(((bits >> 56) & 0xFFUL).to_byte())
}

///|
/// nバイト書き込む
pub fn Writer::write_bytes(self : Writer, data~ : Bytes) -> Unit {
  for i in 0..<data.length() {
    self.buffer.push(data[i])
  }
}

///|
/// Bytesとして出力
pub fn Writer::to_bytes(self : Writer) -> Bytes {
  Bytes::from_array(self.buffer)
}

///|
/// バッファをクリア
pub fn Writer::clear(self : Writer) -> Unit {
  self.buffer = Array::new()
}
