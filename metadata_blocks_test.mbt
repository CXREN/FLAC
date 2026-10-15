///|
/// Typed parsing of the non-STREAMINFO metadata blocks: Vorbis comments,
/// seek tables, pictures, application data and padding.

let vorbis_stream : Bytes =
  b"\x66\x4c\x61\x43\x84\x00\x00\x2c\x07\x00\x00\x00\x4d\x6f\x6f\x6e\x42\x69\x74\x02\x00\x00\x00\x0b\x00\x00\x00\x41\x52\x54\x49\x53\x54\x3d\x54\x65\x73\x74\x0a\x00\x00\x00\x54\x49\x54\x4c\x45\x3d\x53\x6f\x6e\x67"

let seektable_stream : Bytes =
  b"\x66\x4c\x61\x43\x83\x00\x00\x24\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00\x00\x64\x10\x00"

let picture_stream : Bytes =
  b"\x66\x4c\x61\x43\x86\x00\x00\x2b\x00\x00\x00\x03\x00\x00\x00\x09\x69\x6d\x61\x67\x65\x2f\x70\x6e\x67\x00\x00\x00\x00\x00\x00\x01\x2c\x00\x00\x01\x2c\x00\x00\x00\x18\x00\x00\x00\x00\x00\x00\x00\x02\x89\x50"

let app_padding_stream : Bytes =
  b"\x66\x4c\x61\x43\x01\x00\x00\x04\x00\x00\x00\x00\x82\x00\x00\x06\x46\x4c\x41\x43\x01\x02"

test "parse a VORBIS_COMMENT block" {
  let blocks = @flac.parse_metadata_blocks(vorbis_stream)
  assert_true(blocks.length() == 1)
  match blocks[0] {
    @flac.VorbisComment(vc) => {
      assert_true(vc.vendor == "MoonBit")
      assert_true(vc.comments.length() == 2)
      assert_true(vc.comments[0] == "ARTIST=Test")
      assert_true(vc.comments[1] == "TITLE=Song")
    }
    _ => assert_true(false)
  }
}

test "parse a SEEKTABLE block" {
  let blocks = @flac.parse_metadata_blocks(seektable_stream)
  assert_true(blocks.length() == 1)
  match blocks[0] {
    @flac.SeekTable(points) => {
      assert_true(points.length() == 2)
      assert_true(points[0].sample_number == 0L)
      assert_true(points[0].offset == 0L)
      assert_true(points[0].frame_samples == 4096)
      assert_true(points[1].sample_number == 4096L)
      assert_true(points[1].offset == 100L)
      assert_true(points[1].frame_samples == 4096)
    }
    _ => assert_true(false)
  }
}

test "parse a PICTURE block" {
  let blocks = @flac.parse_metadata_blocks(picture_stream)
  assert_true(blocks.length() == 1)
  match blocks[0] {
    @flac.Picture(p) => {
      assert_true(p.picture_type == 3)
      assert_true(p.mime_type == "image/png")
      assert_true(p.description == "")
      assert_true(p.width == 300)
      assert_true(p.height == 300)
      assert_true(p.depth == 24)
      assert_true(p.colors == 0)
      assert_true(p.data.length() == 2)
      assert_true(p.data[0] == b'\x89')
      assert_true(p.data[1] == b'P')
    }
    _ => assert_true(false)
  }
}

test "parse PADDING and APPLICATION blocks in order" {
  let blocks = @flac.parse_metadata_blocks(app_padding_stream)
  assert_true(blocks.length() == 2)
  match blocks[0] {
    @flac.Padding(n) => assert_true(n == 4)
    _ => assert_true(false)
  }
  match blocks[1] {
    @flac.Application(id, data) => {
      assert_true(id == 0x464C4143)
      assert_true(data.length() == 2)
      assert_true(data[0] == b'\x01')
      assert_true(data[1] == b'\x02')
    }
    _ => assert_true(false)
  }
}
