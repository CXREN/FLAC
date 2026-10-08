///|
/// A synthetic `STREAMINFO` block (34 bytes) and a complete `fLaC` +
/// STREAMINFO stream, with hand-checked field values.

let streaminfo_bytes : Bytes =
  b"\x10\x00\x10\x00\x00\x00\x64\x00\x13\x88\x0a\xc4\x42\xf0\x49\x96\x02\xd2\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"

let stream_bytes : Bytes = b"fLaC\x80\x00\x00\x22" + streaminfo_bytes

test "parse_streaminfo decodes every field" {
  let info = @flac.parse_streaminfo(streaminfo_bytes)
  assert_true(info.min_block_size == 4096)
  assert_true(info.max_block_size == 4096)
  assert_true(info.min_frame_size == 100)
  assert_true(info.max_frame_size == 5000)
  assert_true(info.sample_rate == 44100)
  assert_true(info.channels == 2)
  assert_true(info.bits_per_sample == 16)
  assert_true(info.total_samples == 1234567890L)
  assert_true(info.md5[0] == b'\x00')
  assert_true(info.md5[15] == b'\x0F')
}

test "parse_metadata returns the info and the frame offset" {
  let header = @flac.parse_metadata(stream_bytes)
  assert_true(header.info.sample_rate == 44100)
  assert_true(header.info.channels == 2)
  assert_true(header.frame_offset == 42)
}

test "parse_metadata rejects a non-FLAC marker" {
  try {
    let _ = @flac.parse_metadata(b"RIFF\x80\x00\x00\x22" + streaminfo_bytes)
    assert_true(false)
  } catch {
    @flac.NotFlac => assert_true(true)
    _ => assert_true(false)
  }
}

test "parse_metadata skips non-STREAMINFO blocks" {
  // fLaC + PADDING(1, len 4, last=0) + STREAMINFO(last=1)
  let padded = b"fLaC\x01\x00\x00\x04\x00\x00\x00\x00\x80\x00\x00\x22" + streaminfo_bytes
  let header = @flac.parse_metadata(padded)
  assert_true(header.info.sample_rate == 44100)
  assert_true(header.frame_offset == 50)
}

test "parse_metadata requires a STREAMINFO block" {
  try {
    let _ = @flac.parse_metadata(b"fLaC\x84\x00\x00\x00")
    assert_true(false)
  } catch {
    @flac.InvalidMetadata => assert_true(true)
    _ => assert_true(false)
  }
}

test "parse_metadata raises Truncated on a bare marker" {
  try {
    let _ = @flac.parse_metadata(b"fLaC")
    assert_true(false)
  } catch {
    @flac.Truncated => assert_true(true)
    _ => assert_true(false)
  }
}
