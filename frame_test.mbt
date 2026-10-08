///|
/// Frame-header parsing tests over hand-generated bit patterns, covering the
/// fixed codes, the multi-byte UTF-8 frame number, the STREAMINFO fallbacks
/// and the CRC-8 guard.

fn test_info() -> @flac.StreamInfo {
  @flac.StreamInfo::new(512, 512, 0, 0, 44100, 2, 16, 0L, Array::make(16, b'\x00'))
}

fn decode(bits : Bytes) -> @flac.FrameHeader raise @flac.DecodeError {
  let (h, _) = @flac.BitReader::new(bits).read_frame_header(test_info())
  h
}

test "read_frame_header decodes the fixed fields" {
  let h = decode(b"\xff\xf8\x99\x18\x00\xe6")
  assert_true(h.blocking_strategy == 0)
  assert_true(h.block_size == 512)
  assert_true(h.sample_rate == 44100)
  assert_true(h.channels == 2)
  assert_true(h.channel_assignment == 1)
  assert_true(h.bits_per_sample == 16)
  assert_true(h.frame_number == 0L)
  assert_true(h.starting_sample() == 0L)
}

test "read_frame_header decodes a multi-byte UTF-8 frame number" {
  let h = decode(b"\xff\xf8\x99\x18\xc2\x80\xf2")
  assert_true(h.frame_number == 128L)
  assert_true(h.starting_sample() == 65536L)
}

test "read_frame_header falls back to STREAMINFO and reads a 16-bit block size" {
  let h = decode(b"\xff\xf8\x70\x10\x00\x03\xe7\x49")
  assert_true(h.block_size == 1000)
  assert_true(h.sample_rate == 44100)
  assert_true(h.bits_per_sample == 16)
}

test "read_frame_header rejects a header with a bad CRC-8" {
  try {
    let _ = decode(b"\xff\xf8\x99\x18\x00\x19")
    assert_true(false)
  } catch {
    @flac.HeaderCrcMismatch => assert_true(true)
    _ => assert_true(false)
  }
}

test "read_frame_header rejects a bad sync code" {
  try {
    let _ = decode(b"\x00\x00\x00\x00\x00\x00")
    assert_true(false)
  } catch {
    @flac.InvalidFrameSync => assert_true(true)
    _ => assert_true(false)
  }
}
