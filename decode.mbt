///|
/// Whole-frame and whole-stream decoding, producing interleaved PCM samples.

/// One decoded audio frame: its header plus the per-channel samples in
/// standard channel order (left, right, ...).
pub struct DecodedFrame {
  header : FrameHeader
  channels : Array[Array[Int]]
}

/// Decode the frame starting at byte `offset` of `data`, returning the frame
/// and the byte offset of the next frame (just past the CRC-16).
pub fn decode_frame(data : Bytes, offset : Int, info : StreamInfo) -> (DecodedFrame, Int) raise DecodeError {
  let reader = BitReader::new(data).skip(offset * 8)
  let (header, r1) = reader.read_frame_header(info)
  let block_size = header.block_size
  let planar = Array::make(header.channels, Array::make(0, 0))
  let mut r = r1
  for c in 0..<header.channels {
    let (samples, r2) = r.read_subframe(block_size, header.bits_per_sample)
    planar.set(c, samples)
    r = r2
  }
  let channels = decorrelate(planar, header.channel_assignment)
  let aligned = r.align()
  let crc_start = aligned.pos() / 8
  let (stored_crc, r3) = aligned.read_u16()
  let expected = crc16_range(data, offset, crc_start, 0x8005, 0)
  if expected != stored_crc {
    raise FrameCrcMismatch
  }
  ({ header: header, channels: channels }, r3.pos() / 8)
}

/// A decoded PCM stream: the stream properties plus interleaved samples
/// (`[L0, R0, L1, R1, ...]`).
pub struct Pcm {
  sample_rate : Int
  channels : Int
  bits_per_sample : Int
  samples : Array[Int]
}

/// Decode a whole FLAC stream into interleaved PCM, stopping at the end of the
/// audio (or at the first non-frame byte, e.g. trailing tags).
pub fn decode(data : Bytes) -> Pcm raise DecodeError {
  let meta = parse_metadata(data)
  let info = meta.info
  let total = info.total_samples
  let mut offset = meta.frame_offset
  let samples = Array::make(0, 0)
  let mut decoded : Int64 = 0L
  while offset + 2 <= data.length() && (total == 0L || decoded < total) {
    let word = (data[offset].to_int() << 8) | data[offset + 1].to_int()
    if (word & 0xFFFC) != 0xFFF8 {
      break
    }
    let (frame, next) = decode_frame(data, offset, info)
    let n = frame.header.block_size
    let out_channels = frame.channels.length()
    for i in 0..<n {
      for c in 0..<out_channels {
        samples.push(frame.channels[c][i])
      }
    }
    decoded = decoded + Int64::from_int(n)
    offset = next
  }
  let want = if total > 0L {
    (total * Int64::from_int(info.channels)).to_int()
  } else {
    samples.length()
  }
  let trimmed = if want == samples.length() {
    samples
  } else {
    let out = Array::make(want, 0)
    for i in 0..<want {
      out.set(i, samples[i])
    }
    out
  }
  {
    sample_rate: info.sample_rate,
    channels: info.channels,
    bits_per_sample: info.bits_per_sample,
    samples: trimmed,
  }
}
