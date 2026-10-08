///|
/// The `STREAMINFO` metadata block: the fixed 34-byte header every FLAC
/// stream starts with, describing sample rate, channel layout, bit depth and
/// the total sample count.

/// Decoded `STREAMINFO` fields. All sizes are in bytes, the sample rate in Hz,
/// `channels` is 1..=8 and `bits_per_sample` the per-channel PCM bit depth.
pub struct StreamInfo {
  min_block_size : Int
  max_block_size : Int
  min_frame_size : Int
  max_frame_size : Int
  sample_rate : Int
  channels : Int
  bits_per_sample : Int
  total_samples : Int64
  md5 : Array[Byte]
}

/// Build a `StreamInfo` value from already-decoded fields.
pub fn StreamInfo::new(
  min_block_size : Int,
  max_block_size : Int,
  min_frame_size : Int,
  max_frame_size : Int,
  sample_rate : Int,
  channels : Int,
  bits_per_sample : Int,
  total_samples : Int64,
  md5 : Array[Byte]
) -> StreamInfo {
  {
    min_block_size: min_block_size,
    max_block_size: max_block_size,
    min_frame_size: min_frame_size,
    max_frame_size: max_frame_size,
    sample_rate: sample_rate,
    channels: channels,
    bits_per_sample: bits_per_sample,
    total_samples: total_samples,
    md5: md5,
  }
}

/// Parse a 34-byte `STREAMINFO` block from a byte-aligned reader, returning the
/// decoded info and the reader advanced past the block.
pub fn BitReader::read_streaminfo(self : BitReader) -> (StreamInfo, BitReader) raise DecodeError {
  let (min_block, r1) = self.read_u16()
  let (max_block, r2) = r1.read_u16()
  let (min_frame, r3) = r2.read_u24()
  let (max_frame, r4) = r3.read_u24()
  let (sample_rate, r5) = r4.read_bits(20)
  let (ch, r6) = r5.read_bits(3)
  let (bps, r7) = r6.read_bits(5)
  let (hi, r8) = r7.read_bits(4)
  let (lo, r9) = r8.read_bits(32)
  let total = (Int64::from_int(hi) << 32) | (Int64::from_int(lo) & 4294967295L)
  let mut r = r9
  let md5 = Array::make(16, b'\x00')
  for i in 0..<16 {
    let (b, rr) = r.read_byte()
    md5.set(i, b.to_byte())
    r = rr
  }
  (StreamInfo::new(min_block, max_block, min_frame, max_frame, sample_rate, ch + 1, bps + 1, total, md5), r)
}

/// Parse a standalone 34-byte `STREAMINFO` block.
pub fn parse_streaminfo(data : Bytes) -> StreamInfo raise DecodeError {
  if data.length() != 34 {
    raise InvalidMetadata
  }
  let (info, _) = BitReader::new(data).read_streaminfo()
  info
}
