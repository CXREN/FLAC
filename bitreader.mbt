///|
/// A forward-only bit reader over a byte buffer, reading bits most-significant
/// first — the big-endian convention used throughout FLAC.
///
/// The reader is immutable: every read returns the value together with the
/// advanced reader. A `BitReader` value is therefore always a pure cursor into
/// the source buffer, and the buffer itself is never copied.

pub struct BitReader {
  data : Bytes
  pos : Int
}

/// Wrap a byte buffer for bit reading.
pub fn BitReader::new(data : Bytes) -> BitReader {
  { data: data, pos: 0 }
}

/// The current bit position, counted from the first bit of the buffer.
pub fn BitReader::pos(self : BitReader) -> Int {
  self.pos
}

/// The number of bits still available after the current position.
pub fn BitReader::remaining(self : BitReader) -> Int {
  self.data.length() * 8 - self.pos
}

/// True when at least `n` more bits are available.
pub fn BitReader::has(self : BitReader, n : Int) -> Bool {
  self.pos + n <= self.data.length() * 8
}

/// The underlying source buffer (for CRC checks over byte ranges).
pub fn BitReader::data(self : BitReader) -> Bytes {
  self.data
}

/// Read a single bit as `0` or `1`.
pub fn BitReader::read_bit(self : BitReader) -> (Int, BitReader) raise DecodeError {
  self.read_bits(1)
}

/// Read `n` bits (`0 <= n <= 32`) as an unsigned integer, MSB first.
///
/// For `n == 32` the raw pattern is returned as an `Int`, which may be negative
/// when the top bit is set; use `read_u32` for an unsigned view.
pub fn BitReader::read_bits(self : BitReader, n : Int) -> (Int, BitReader) raise DecodeError {
  if n < 0 || n > 32 {
    raise InvalidBitCount
  }
  if !self.has(n) {
    raise Truncated
  }
  let mut value = 0
  let mut pos = self.pos
  let mut taken = 0
  while taken < n {
    let byte = self.data[pos / 8].to_int()
    let avail = 8 - pos % 8
    let want = n - taken
    let take = if want < avail { want } else { avail }
    let shift = avail - take
    let bits = (byte >> shift) & ((1 << take) - 1)
    value = (value << take) | bits
    pos = pos + take
    taken = taken + take
  }
  (value, { data: self.data, pos: pos })
}

/// Read `n` bits as a signed two's-complement integer (sign-extended to 32 bits).
pub fn BitReader::read_signed(self : BitReader, n : Int) -> (Int, BitReader) raise DecodeError {
  if n == 0 {
    return (0, self)
  }
  let (u, r) = self.read_bits(n)
  ((u << (32 - n)) >> (32 - n), r)
}

/// Read a unary-coded non-negative integer: the number of `0` bits terminated
/// by a single `1` bit.
pub fn BitReader::read_unary(self : BitReader) -> (Int, BitReader) raise DecodeError {
  let mut count = 0
  let mut r = self
  while true {
    if !r.has(1) {
      raise Truncated
    }
    let (bit, next) = r.read_unchecked_bit()
    r = next
    if bit == 1 {
      break (count, r)
    }
    count = count + 1
  } nobreak {
    raise Truncated
  }
}

/// Skip `n` bits without reading them.
pub fn BitReader::skip(self : BitReader, n : Int) -> BitReader raise DecodeError {
  if n < 0 || !self.has(n) {
    raise Truncated
  }
  { data: self.data, pos: self.pos + n }
}

/// Advance to the next byte boundary (a no-op when already aligned).
pub fn BitReader::align(self : BitReader) -> BitReader {
  let rem = self.pos % 8
  if rem == 0 {
    self
  } else {
    { data: self.data, pos: self.pos + 8 - rem }
  }
}

/// Read one whole byte (8 bits) as an unsigned integer.
pub fn BitReader::read_byte(self : BitReader) -> (Int, BitReader) raise DecodeError {
  self.read_bits(8)
}

/// Read a big-endian unsigned 16-bit integer.
pub fn BitReader::read_u16(self : BitReader) -> (Int, BitReader) raise DecodeError {
  self.read_bits(16)
}

/// Read a big-endian unsigned 24-bit integer.
pub fn BitReader::read_u24(self : BitReader) -> (Int, BitReader) raise DecodeError {
  self.read_bits(24)
}

/// Read a big-endian unsigned 32-bit integer as a `UInt`.
pub fn BitReader::read_u32(self : BitReader) -> (UInt, BitReader) raise DecodeError {
  let (v, r) = self.read_bits(32)
  (v.reinterpret_as_uint(), r)
}

/// Read a FLAC-style UTF-8 coded non-negative integer (7 to 36 bits). The
/// number of leading `1` bits in the first byte gives the total byte count.
pub fn BitReader::read_utf8_number(self : BitReader) -> (Int64, BitReader) raise DecodeError {
  let (b0, r1) = self.read_byte()
  if (b0 & 0x80) == 0 {
    return (Int64::from_int(b0), r1)
  }
  let mut len = 0
  let mut mask = 0x80
  while (b0 & mask) != 0 {
    len = len + 1
    mask = mask >> 1
  }
  if len == 1 || len > 7 {
    raise InvalidFrameHeader
  }
  let mut value : Int64 = Int64::from_int(b0 & ((1 << (7 - len)) - 1))
  let mut r = r1
  for _ in 0..<(len - 1) {
    let (b, rr) = r.read_byte()
    if (b & 0xC0) != 0x80 {
      raise InvalidFrameHeader
    }
    value = (value << 6) | Int64::from_int(b & 0x3F)
    r = rr
  }
  (value, r)
}

/// Read a single bit without bounds checking. The caller must have verified
/// availability with `has(1)` first.
fn BitReader::read_unchecked_bit(self : BitReader) -> (Int, BitReader) {
  let byte = self.data[self.pos / 8].to_int()
  let bit = (byte >> (7 - self.pos % 8)) & 1
  (bit, { data: self.data, pos: self.pos + 1 })
}
