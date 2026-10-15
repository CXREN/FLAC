///|
/// MD5 message digest (RFC 1321). FLAC stores an MD5 signature of the raw
/// audio samples in its `STREAMINFO` block, so this module lets a decoder
/// check stream integrity end-to-end. The digest is computed with the
/// standard 64-round Merkle–Damgård construction over little-endian words.

/// The 64 per-round additive constants: `floor(abs(sin(i + 1)) * 2^32)`.
let k : Array[UInt] = [
  0xd76aa478U, 0xe8c7b756U, 0x242070dbU, 0xc1bdceeeU,
  0xf57c0fafU, 0x4787c62aU, 0xa8304613U, 0xfd469501U,
  0x698098d8U, 0x8b44f7afU, 0xffff5bb1U, 0x895cd7beU,
  0x6b901122U, 0xfd987193U, 0xa679438eU, 0x49b40821U,
  0xf61e2562U, 0xc040b340U, 0x265e5a51U, 0xe9b6c7aaU,
  0xd62f105dU, 0x02441453U, 0xd8a1e681U, 0xe7d3fbc8U,
  0x21e1cde6U, 0xc33707d6U, 0xf4d50d87U, 0x455a14edU,
  0xa9e3e905U, 0xfcefa3f8U, 0x676f02d9U, 0x8d2a4c8aU,
  0xfffa3942U, 0x8771f681U, 0x6d9d6122U, 0xfde5380cU,
  0xa4beea44U, 0x4bdecfa9U, 0xf6bb4b60U, 0xbebfbc70U,
  0x289b7ec6U, 0xeaa127faU, 0xd4ef3085U, 0x04881d05U,
  0xd9d4d039U, 0xe6db99e5U, 0x1fa27cf8U, 0xc4ac5665U,
  0xf4292244U, 0x432aff97U, 0xab9423a7U, 0xfc93a039U,
  0x655b59c3U, 0x8f0ccc92U, 0xffeff47dU, 0x85845dd1U,
  0x6fa87e4fU, 0xfe2ce6e0U, 0xa3014314U, 0x4e0811a1U,
  0xf7537e82U, 0xbd3af235U, 0x2ad7d2bbU, 0xeb86d391U,
]

/// The left-rotation amount for each of the 64 rounds.
let s : Array[Int] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
]

/// Rotate `x` left by `n` bits (0 < n < 32).
fn rotl(x : UInt, n : Int) -> UInt {
  (x << n) | (x >> (32 - n))
}

/// Read one 32-bit little-endian word from `buf` at byte offset `pos`.
fn read_le32(buf : Array[Byte], pos : Int) -> UInt {
  let b0 = buf[pos].to_int().reinterpret_as_uint()
  let b1 = buf[pos + 1].to_int().reinterpret_as_uint()
  let b2 = buf[pos + 2].to_int().reinterpret_as_uint()
  let b3 = buf[pos + 3].to_int().reinterpret_as_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

/// Write `v` to `out` as a 32-bit little-endian value.
fn write_le32(out : Array[Byte], pos : Int, v : UInt) -> Unit {
  for i in 0..<4 {
    out.set(pos + i, ((v >> (8 * i)) & 0xFFU).reinterpret_as_int().to_byte())
  }
}

/// Compress one 64-byte block into the running state.
fn block(a0 : UInt, b0 : UInt, c0 : UInt, d0 : UInt, m : Array[UInt]) -> (UInt, UInt, UInt, UInt) {
  let mut a = a0
  let mut b = b0
  let mut c = c0
  let mut d = d0
  for i in 0..<64 {
    let (f, g) = if i < 16 {
      ((b & c) | (b.lnot() & d), i)
    } else if i < 32 {
      ((d & b) | (d.lnot() & c), (5 * i + 1) % 16)
    } else if i < 48 {
      (b ^ c ^ d, (3 * i + 5) % 16)
    } else {
      (c ^ (b | d.lnot()), (7 * i) % 16)
    }
    let temp = d
    d = c
    c = b
    b = b + rotl(a + f + k[i] + m[g], s[i])
    a = temp
  }
  (a0 + a, b0 + b, c0 + c, d0 + d)
}

/// Compute the 16-byte MD5 digest of `data`.
pub fn md5(data : Bytes) -> Bytes {
  let len = data.length()
  // Append a 0x80 marker, pad with zeroes to 8 bytes short of a 64-byte
  // multiple, then append the original bit length as 8 little-endian bytes.
  let padded_len = ((len + 72) / 64) * 64
  let buf = Array::make(padded_len, b'\x00')
  for i in 0..<len {
    buf.set(i, data[i])
  }
  buf.set(len, b'\x80')
  let bit_len : Int64 = Int64::from_int(len) << 3
  for i in 0..<8 {
    buf.set(padded_len - 8 + i, ((bit_len >> (8 * i)) & 0xFFL).to_int().to_byte())
  }
  let mut a = 0x67452301U
  let mut b = 0xefcdab89U
  let mut c = 0x98badcfeU
  let mut d = 0x10325476U
  let mut pos = 0
  while pos < padded_len {
    let m = Array::make(16, 0U)
    for j in 0..<16 {
      m.set(j, read_le32(buf, pos + j * 4))
    }
    let (a2, b2, c2, d2) = block(a, b, c, d, m)
    a = a2
    b = b2
    c = c2
    d = d2
    pos = pos + 64
  }
  let out = Array::make(16, b'\x00')
  write_le32(out, 0, a)
  write_le32(out, 4, b)
  write_le32(out, 8, c)
  write_le32(out, 12, d)
  Bytes::from_array(out)
}

fn hex_digit(v : Int) -> Byte {
  if v < 10 {
    (48 + v).to_byte()
  } else {
    (87 + v).to_byte()
  }
}

/// Render bytes as a lowercase hexadecimal string.
pub fn hex(data : Bytes) -> String {
  let out = Array::make(data.length() * 2, b'\x00')
  for i in 0..<data.length() {
    let b = data[i].to_int()
    out.set(i * 2, hex_digit(b >> 4))
    out.set(i * 2 + 1, hex_digit(b & 0x0F))
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}

/// The MD5 digest of `data` as a 32-character lowercase hex string.
pub fn md5_hex(data : Bytes) -> String {
  hex(md5(data))
}

/// The MD5 signature stored in a `STREAMINFO` block, as hex. Pair it with
/// `md5_hex` over the decoded samples to verify a stream's integrity.
pub fn StreamInfo::md5_hex(self : StreamInfo) -> String {
  hex(Bytes::from_array(self.md5))
}
