///|
/// `BitReader` reads MSB-first, so the byte `0x80` yields `1` for its first
/// bit and `0x0F 0xF0` splits as `0000` then `1111 1111`.

test "read_bits within one byte" {
  let r = @flac.BitReader::new(b"\x80")
  let (hi, _) = r.read_bits(1)
  assert_true(hi == 1)
  let (all, _) = r.read_bits(8)
  assert_true(all == 0x80)
  let r2 = @flac.BitReader::new(b"\xFF")
  let (v, _) = r2.read_bits(8)
  assert_true(v == 255)
}

test "read_bits across a byte boundary" {
  let r = @flac.BitReader::new(b"\x0F\xF0")
  let (lo, r1) = r.read_bits(4)
  assert_true(lo == 0)
  let (hi, _) = r1.read_bits(8)
  assert_true(hi == 0xFF)
}

test "read_bits of zero width is a no-op" {
  let r = @flac.BitReader::new(b"\x00")
  let (v, r1) = r.read_bits(0)
  assert_true(v == 0)
  assert_true(r1.pos() == 0)
}

test "read_signed sign-extends" {
  let r = @flac.BitReader::new(b"\xFF\xF0")
  let (a, _) = r.read_signed(12)
  assert_true(a == -1)
  let r2 = @flac.BitReader::new(b"\x80")
  let (b, _) = r2.read_signed(8)
  assert_true(b == -128)
  let r3 = @flac.BitReader::new(b"\x7F")
  let (c, _) = r3.read_signed(8)
  assert_true(c == 127)
}

test "read_unary counts leading zeroes" {
  let r = @flac.BitReader::new(b"\x80")
  let (a, _) = r.read_unary()
  assert_true(a == 0)
  let r2 = @flac.BitReader::new(b"\x00\x80")
  let (b, _) = r2.read_unary()
  assert_true(b == 8)
  let r3 = @flac.BitReader::new(b"\x0F\x80")
  // 0000 1111 1000 0000 -> four zero bits then a one
  let (c, _) = r3.read_unary()
  assert_true(c == 4)
}

test "read_byte and fixed-width integers" {
  let r = @flac.BitReader::new(b"\x12\x34")
  let (a, _) = r.read_u16()
  assert_true(a == 0x1234)
  let r2 = @flac.BitReader::new(b"\x01\x02\x03")
  let (b, _) = r2.read_u24()
  assert_true(b == 0x010203)
  let r3 = @flac.BitReader::new(b"\x00\x00\x00\x2A")
  let (c, _) = r3.read_u32()
  assert_true(c.reinterpret_as_int() == 42)
}

test "skip and align advance the cursor" {
  let r = @flac.BitReader::new(b"\xFF\xFF")
  let r1 = r.skip(8)
  assert_true(r1.pos() == 8)
  let r2 = r.read_bits(3).1
  let r3 = r2.align()
  assert_true(r3.pos() == 8)
}

test "remaining and has report availability" {
  let r = @flac.BitReader::new(b"\x00\x00")
  assert_true(r.remaining() == 16)
  assert_true(r.has(16))
  assert_true(!r.has(17))
}

fn read_bits_errors(data : Bytes, n : Int) -> Bool {
  let r = @flac.BitReader::new(data)
  try {
    let (_, _) = r.read_bits(n)
    false
  } catch {
    _ => true
  }
}

test "read_bits raises Truncated when out of data" {
  assert_true(read_bits_errors(b"\x01", 9))
  assert_true(!read_bits_errors(b"\x01", 8))
  assert_true(read_bits_errors(b"", 1))
}

test "read_bits raises InvalidBitCount for bad widths" {
  assert_true(read_bits_errors(b"\x00\x00\x00\x00\x00", 33))
  assert_true(read_bits_errors(b"\x00", -1))
}
