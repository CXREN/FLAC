///|
/// Subframe decoding tests over hand-generated subframes, covering the four
/// subframe types, escaped Rice partitions and wasted-bits handling.

fn subframe(bits : Bytes, block_size : Int, bps : Int) -> Array[Int] raise @flac.DecodeError {
  let (samples, _) = @flac.BitReader::new(bits).read_subframe(block_size, bps)
  samples
}

fn assert_subframe(actual : Array[Int], expected : Array[Int]) -> Unit raise {
  assert_true(actual.length() == expected.length())
  for i in 0..<actual.length() {
    assert_true(actual[i] == expected[i])
  }
}

test "constant subframe repeats a single sample" {
  assert_subframe(
    subframe(b"\x00\x03\xe8", 16, 16),
    [1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000],
  )
}

test "verbatim subframe decodes each sample" {
  assert_subframe(
    subframe(b"\x02\x00\x00\x00\x64\xff\x9c\x00\xc8\xff\x38\x01\xf4\xfe\x0c\x03\xe8\xfc\x18\x07\xd0\xf8\x30\x13\x88\xec\x78\x27\x10\xd8\xf0\x30\x39", 16, 16),
    [0, 100, -100, 200, -200, 500, -500, 1000, -1000, 2000, -2000, 5000, -5000, 10000, -10000, 12345],
  )
}

test "fixed order 2 subframe runs the fixed predictor" {
  assert_subframe(
    subframe(b"\x14\x00\x0a\x00\x0c\x00\xea\xaa\xaa\xaa\xaa\xaa\xaa\x80", 16, 16),
    [10, 12, 15, 19, 24, 30, 37, 45, 54, 64, 75, 87, 100, 114, 129, 145],
  )
}

test "lpc order 1 subframe runs the linear predictor" {
  assert_subframe(
    subframe(b"\x40\x00\x05\x10\x20\x1f\x77\x77\x77\x77\x77\x77\x77\x00", 16, 16),
    [5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35, 38, 41, 44, 47, 50],
  )
}

test "escaped residual partition reads raw samples" {
  assert_subframe(subframe(b"\x10\x03\xc8\x3c\x78", 4, 16), [1, -2, 3, -4])
}

test "wasted bits shift samples back into place" {
  assert_subframe(subframe(b"\x03\x40\x01\x00\x08\x00\x30\x01\x00", 4, 16), [4, 8, 12, 16])
}
