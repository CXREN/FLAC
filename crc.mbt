///|
/// Bit-by-bit big-endian (MSB-first) CRC helpers, with the two polynomials
/// used by FLAC: CRC-8 for frame headers and CRC-16 for whole frames.
///
/// The implementations mirror the reference algorithms in RFC 9639 and
/// `libFLAC`, so they accept arbitrary byte ranges without a lookup table.

/// CRC-8 over the byte range `[from, to)` with the given polynomial and
/// initial value, processing bits most-significant first.
pub fn crc8_range(data : Bytes, from : Int, to : Int, poly : Int, init : Int) -> Int {
  let mut crc = init
  for i = from; i < to; i = i + 1 {
    crc = crc ^ data[i].to_int()
    for _ in 0..<8 {
      if (crc & 0x80) != 0 {
        crc = ((crc << 1) ^ poly) & 0xFF
      } else {
        crc = (crc << 1) & 0xFF
      }
    }
  }
  crc
}

/// CRC-16 over the byte range `[from, to)` with the given polynomial and
/// initial value, processing bits most-significant first.
pub fn crc16_range(data : Bytes, from : Int, to : Int, poly : Int, init : Int) -> Int {
  let mut crc = init
  for i = from; i < to; i = i + 1 {
    crc = crc ^ (data[i].to_int() << 8)
    for _ in 0..<8 {
      if (crc & 0x8000) != 0 {
        crc = ((crc << 1) ^ poly) & 0xFFFF
      } else {
        crc = (crc << 1) & 0xFFFF
      }
    }
  }
  crc
}

/// CRC-8 over a whole buffer with the given polynomial and initial value.
pub fn crc8(data : Bytes, poly : Int, init : Int) -> Int {
  crc8_range(data, 0, data.length(), poly, init)
}

/// CRC-16 over a whole buffer with the given polynomial and initial value.
pub fn crc16(data : Bytes, poly : Int, init : Int) -> Int {
  crc16_range(data, 0, data.length(), poly, init)
}

/// FLAC frame-header CRC-8 (polynomial `x^8 + x^2 + x + 1` = `0x07`, init `0`).
pub fn crc8_flac(data : Bytes) -> Int {
  crc8(data, 0x07, 0)
}

/// FLAC frame CRC-16 (polynomial `x^16 + x^15 + x^2 + 1` = `0x8005`, init `0`).
pub fn crc16_flac(data : Bytes) -> Int {
  crc16(data, 0x8005, 0)
}
