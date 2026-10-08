///|
/// Top-of-stream parsing: the `fLaC` marker and the metadata-block chain that
/// precedes the audio frames.

/// The result of parsing a stream's metadata: the `STREAMINFO` block plus the
/// byte offset where the first audio frame begins.
pub struct FlacHeader {
  info : StreamInfo
  frame_offset : Int
}

/// Parse the `fLaC` marker and metadata blocks, returning the decoded
/// `STREAMINFO` and the offset of the first audio frame.
///
/// Non-`STREAMINFO` blocks (padding, seek tables, comments, pictures, ...) are
/// skipped. The first metadata block must be a `STREAMINFO`.
pub fn parse_metadata(data : Bytes) -> FlacHeader raise DecodeError {
  if data.length() < 4 {
    raise Truncated
  }
  if data[0] != b'f' || data[1] != b'L' || data[2] != b'a' || data[3] != b'C' {
    raise NotFlac
  }
  let mut r = BitReader::new(data).skip(32)
  let mut info : StreamInfo? = None
  let mut done = false
  while !done {
    let (header, r1) = r.read_byte()
    let is_last = (header & 0x80) != 0
    let block_type = header & 0x7F
    let (len, r2) = r1.read_u24()
    if block_type == 0 {
      if len != 34 {
        raise InvalidMetadata
      }
      let (si, r3) = r2.read_streaminfo()
      info = Some(si)
      r = r3
    } else {
      r = r2.skip(len * 8)
    }
    if is_last {
      done = true
    }
  }
  match info {
    Some(si) => { info: si, frame_offset: r.pos() / 8 }
    None => raise InvalidMetadata
  }
}
