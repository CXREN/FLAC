///|
/// CRC vectors are the reference check values from RFC 9639 / libFLAC:
/// CRC-8 (poly 0x07, init 0) and CRC-16 (poly 0x8005, init 0), both
/// bit-by-bit MSB-first with no final XOR.

test "crc8 matches the standard check value" {
  assert_true(@flac.crc8(b"123456789", 0x07, 0) == 0xF4)
}

test "crc8 flac convenience matches" {
  assert_true(@flac.crc8_flac(b"123456789") == 0xF4)
}

test "crc8 empty and single bytes" {
  assert_true(@flac.crc8(b"", 0x07, 0) == 0x00)
  assert_true(@flac.crc8(b"\x00", 0x07, 0) == 0x00)
  assert_true(@flac.crc8(b"\xFF", 0x07, 0) == 0xF3)
}

test "crc16 matches the standard check value" {
  assert_true(@flac.crc16(b"123456789", 0x8005, 0) == 0xFEE8)
}

test "crc16 flac convenience matches" {
  assert_true(@flac.crc16_flac(b"123456789") == 0xFEE8)
}

test "crc16 empty and single bytes" {
  assert_true(@flac.crc16(b"", 0x8005, 0) == 0x0000)
  assert_true(@flac.crc16(b"\x00", 0x8005, 0) == 0x0000)
  assert_true(@flac.crc16(b"\x01", 0x8005, 0) == 0x8005)
  assert_true(@flac.crc16(b"\x80", 0x8005, 0) == 0x8303)
}

test "crc over a sub-range" {
  let data = b"\x00\x01\x02\x03\x04"
  // Range [0, 4) is \x00\x01\x02\x03; range [1, 5) is \x01\x02\x03\x04.
  assert_true(@flac.crc16_range(data, 0, 4, 0x8005, 0) == 0xC1E)
  assert_true(@flac.crc16_range(data, 1, 5, 0x8005, 0) == @flac.crc16(b"\x01\x02\x03\x04", 0x8005, 0))
}
