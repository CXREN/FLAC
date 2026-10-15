///|
/// Top-of-stream parsing: the `fLaC` marker and the metadata-block chain that
/// precedes the audio frames. Besides `STREAMINFO`, the non-audio blocks —
/// padding, application data, seek tables, Vorbis comments and pictures — are
/// decoded into typed values rather than skipped.

/// The result of parsing a stream's metadata: the `STREAMINFO` block plus the
/// byte offset where the first audio frame begins.
pub struct FlacHeader {
  info : StreamInfo
  frame_offset : Int
}

/// One entry of a `SEEKTABLE` block: a sample number, the byte offset of the
/// frame that starts there, and that frame's sample count.
pub struct SeekPoint {
  sample_number : Int64
  offset : Int64
  frame_samples : Int
}

/// A `VORBIS_COMMENT` block: a vendor string plus the list of
/// `KEY=value` comment strings.
pub struct VorbisComment {
  vendor : String
  comments : Array[String]
}

/// A `PICTURE` block: the embedded cover art and its dimensions.
pub struct Picture {
  picture_type : Int
  mime_type : String
  description : String
  width : Int
  height : Int
  depth : Int
  colors : Int
  data : Bytes
}

/// One decoded metadata block, tagged by type.
pub enum MetadataBlock {
  StreamInfo(StreamInfo)
  Padding(Int)
  Application(Int, Bytes)
  SeekTable(Array[SeekPoint])
  VorbisComment(VorbisComment)
  Picture(Picture)
  Other(Int, Bytes)
}

/// Read `n` whole bytes from the (byte-aligned) reader into a fresh buffer.
fn read_bytes(r : BitReader, n : Int) -> (Bytes, BitReader) raise DecodeError {
  if n < 0 {
    raise InvalidMetadata
  }
  let start = r.pos() / 8
  let data = r.data()
  if start + n > data.length() {
    raise Truncated
  }
  let out = Array::make(n, b'\x00')
  for i in 0..<n {
    out.set(i, data[start + i])
  }
  (Bytes::from_array(out), r.skip(n * 8))
}

/// Read `n` whole bytes and decode them as a UTF-8 string. Malformed UTF-8 is
/// replaced with U+FFFD rather than failing the whole stream.
fn read_string(r : BitReader, n : Int) -> (String, BitReader) raise DecodeError {
  let (bytes, r1) = read_bytes(r, n)
  (@utf8.decode_lossy(bytes), r1)
}

/// Read a big-endian unsigned 64-bit integer (two 32-bit halves, reassembled
/// without sign loss).
fn read_u64_be(r : BitReader) -> (Int64, BitReader) raise DecodeError {
  let (hi, r1) = r.read_bits(32)
  let (lo, r2) = r1.read_bits(32)
  let hi64 = Int64::from_int(hi) & 4294967295L
  let lo64 = Int64::from_int(lo) & 4294967295L
  ((hi64 << 32) | lo64, r2)
}

/// Read a little-endian unsigned 32-bit integer (Vorbis comments store their
/// lengths little-endian, unlike the rest of FLAC).
fn read_u32_le(r : BitReader) -> (Int, BitReader) raise DecodeError {
  let (b0, r1) = r.read_byte()
  let (b1, r2) = r1.read_byte()
  let (b2, r3) = r2.read_byte()
  let (b3, r4) = r3.read_byte()
  let value = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  if value < 0 {
    raise InvalidMetadata
  }
  (value, r4)
}

/// Parse the content of one metadata block (already extracted as `content`).
fn parse_block_content(block_type : Int, content : Bytes) -> MetadataBlock raise DecodeError {
  let r = BitReader::new(content)
  if block_type == 0 {
    let (si, _) = r.read_streaminfo()
    StreamInfo(si)
  } else if block_type == 1 {
    Padding(content.length())
  } else if block_type == 2 {
    if content.length() < 4 {
      raise InvalidMetadata
    }
    let (id, r1) = r.read_bits(32)
    let (data, _) = read_bytes(r1, content.length() - 4)
    Application(id, data)
  } else if block_type == 3 {
    if content.length() % 18 != 0 {
      raise InvalidMetadata
    }
    let count = content.length() / 18
    let points = Array::make(0, { sample_number: 0L, offset: 0L, frame_samples: 0 })
    let mut rr = r
    for _ in 0..<count {
      let (sample_number, r1) = read_u64_be(rr)
      let (offset, r2) = read_u64_be(r1)
      let (frame_samples, r3) = r2.read_u16()
      points.push({ sample_number: sample_number, offset: offset, frame_samples: frame_samples })
      rr = r3
    }
    SeekTable(points)
  } else if block_type == 4 {
    let (vendor_len, r1) = read_u32_le(r)
    let (vendor, r2) = read_string(r1, vendor_len)
    let (count, r3) = read_u32_le(r2)
    let comments = Array::make(0, "")
    let mut rr = r3
    for _ in 0..<count {
      let (clen, r4) = read_u32_le(rr)
      let (c, r5) = read_string(r4, clen)
      comments.push(c)
      rr = r5
    }
    VorbisComment({ vendor: vendor, comments: comments })
  } else if block_type == 6 {
    let (picture_type, r1) = r.read_bits(32)
    let (mime_len, r2) = r1.read_bits(32)
    let (mime_type, r3) = read_string(r2, mime_len)
    let (desc_len, r4) = r3.read_bits(32)
    let (description, r5) = read_string(r4, desc_len)
    let (width, r6) = r5.read_bits(32)
    let (height, r7) = r6.read_bits(32)
    let (depth, r8) = r7.read_bits(32)
    let (colors, r9) = r8.read_bits(32)
    let (data_len, r10) = r9.read_bits(32)
    let (data, _) = read_bytes(r10, data_len)
    Picture({
      picture_type: picture_type,
      mime_type: mime_type,
      description: description,
      width: width,
      height: height,
      depth: depth,
      colors: colors,
      data: data,
    })
  } else {
    Other(block_type, content)
  }
}

/// Read one metadata block: its typed content plus the reader just past it.
fn read_block(r : BitReader, block_type : Int, len : Int) -> (MetadataBlock, BitReader) raise DecodeError {
  let (content, r1) = read_bytes(r, len)
  let block = try {
    parse_block_content(block_type, content)
  } catch {
    _ => raise InvalidMetadata
  }
  (block, r1)
}

/// Parse the `fLaC` marker and the whole metadata-block chain, returning the
/// decoded blocks and the byte offset of the first audio frame.
fn parse_chain(data : Bytes) -> (Array[MetadataBlock], Int) raise DecodeError {
  if data.length() < 4 {
    raise Truncated
  }
  if data[0] != b'f' || data[1] != b'L' || data[2] != b'a' || data[3] != b'C' {
    raise NotFlac
  }
  let blocks = Array::make(0, Other(0, b""))
  let mut r = BitReader::new(data).skip(32)
  let mut done = false
  while !done {
    let (header, r1) = r.read_byte()
    let is_last = (header & 0x80) != 0
    let block_type = header & 0x7F
    let (len, r2) = r1.read_u24()
    let (block, r3) = read_block(r2, block_type, len)
    blocks.push(block)
    r = r3
    if is_last {
      done = true
    }
  }
  (blocks, r.pos() / 8)
}

/// Decode every metadata block in the stream.
pub fn parse_metadata_blocks(data : Bytes) -> Array[MetadataBlock] raise DecodeError {
  parse_chain(data).0
}

/// Parse the `fLaC` marker and metadata blocks, returning the decoded
/// `STREAMINFO` and the offset of the first audio frame.
///
/// The first block must be a `STREAMINFO`; other blocks are decoded and, if
/// they are not a `STREAMINFO`, ignored here (use `parse_metadata_blocks` to
/// keep them).
pub fn parse_metadata(data : Bytes) -> FlacHeader raise DecodeError {
  let (blocks, frame_offset) = parse_chain(data)
  let mut info : StreamInfo? = None
  for b in blocks {
    match b {
      StreamInfo(si) => info = Some(si)
      _ => ()
    }
  }
  match info {
    Some(si) => { info: si, frame_offset: frame_offset }
    None => raise InvalidMetadata
  }
}
