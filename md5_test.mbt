///|
/// MD5 against the RFC 1321 known-answer test vectors, plus the hex renderer
/// and the STREAMINFO signature helper.

test "md5 of the empty string" {
  assert_true(@flac.md5_hex(b"") == "d41d8cd98f00b204e9800998ecf8427e")
}

test "md5 of \"abc\"" {
  assert_true(@flac.md5_hex(b"abc") == "900150983cd24fb0d6963f7d28e17f72")
}

test "md5 of a single character" {
  assert_true(@flac.md5_hex(b"a") == "0cc175b9c0f1b6a831c399e269772661")
}

test "md5 of \"message digest\"" {
  assert_true(@flac.md5_hex(b"message digest") == "f96b697d7cb7938d525a2f31aaf161d0")
}

test "md5 of the lowercase alphabet" {
  assert_true(@flac.md5_hex(b"abcdefghijklmnopqrstuvwxyz") == "c3fcd3d76192e4007dfb496cca67e13b")
}

test "md5 of the alphanumeric alphabet" {
  assert_true(
    @flac.md5_hex(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") ==
      "d174ab98d277d9f5a5611c2c9f419d9f"
  )
}

test "md5 of 80 digits" {
  assert_true(
    @flac.md5_hex(b"12345678901234567890123456789012345678901234567890123456789012345678901234567890") ==
      "57edf4a22be3c955ac49da2e2107b67a"
  )
}

test "md5 spans multiple 64-byte blocks" {
  assert_true(@flac.md5_hex(b"abcdefghijklmnopqrstuvwxyz") == "c3fcd3d76192e4007dfb496cca67e13b")
  assert_true(@flac.md5_hex(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") == "d174ab98d277d9f5a5611c2c9f419d9f")
}

test "md5 raw digest bytes of \"abc\"" {
  let d = @flac.md5(b"abc")
  assert_true(d.length() == 16)
  let expected : Bytes = b"\x90\x01\x50\x98\x3c\xd2\x4f\xb0\xd6\x96\x3f\x7d\x28\xe1\x7f\x72"
  assert_true(d == expected)
}

test "hex renders bytes as lowercase" {
  assert_true(@flac.hex(b"\x00\xff\x10\xab") == "00ff10ab")
}

test "StreamInfo::md5_hex renders the stored signature" {
  let si = @flac.StreamInfo::new(
    4096,
    4096,
    0,
    0,
    44100,
    2,
    16,
    0L,
    [
      b'\x90', b'\x01', b'\x50', b'\x98', b'\x3c', b'\xd2', b'\x4f', b'\xb0',
      b'\xd6', b'\x96', b'\x3f', b'\x7d', b'\x28', b'\xe1', b'\x7f', b'\x72',
    ]
  )
  assert_true(si.md5_hex() == "900150983cd24fb0d6963f7d28e17f72")
}
