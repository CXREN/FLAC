///|
/// Audio frame headers: the 14-bit sync code, block size / sample rate /
/// channel / sample size codes, the UTF-8 coded frame number and the CRC-8
/// that protects the header.

/// Decoded frame header. `frame_number` is the frame number for fixed-size
/// blocks and the starting sample number for variable-size blocks.
pub struct FrameHeader {
  blocking_strategy : Int
  block_size : Int
  sample_rate : Int
  channels : Int
  channel_assignment : Int
  bits_per_sample : Int
  frame_number : Int64
}

/// Build a `FrameHeader` from already-decoded fields.
pub fn FrameHeader::new(
  blocking_strategy : Int,
  block_size : Int,
  sample_rate : Int,
  channels : Int,
  channel_assignment : Int,
  bits_per_sample : Int,
  frame_number : Int64
) -> FrameHeader {
  {
    blocking_strategy: blocking_strategy,
    block_size: block_size,
    sample_rate: sample_rate,
    channels: channels,
    channel_assignment: channel_assignment,
    bits_per_sample: bits_per_sample,
    frame_number: frame_number,
  }
}

/// The absolute sample index at which this frame's audio starts.
pub fn FrameHeader::starting_sample(self : FrameHeader) -> Int64 {
  if self.blocking_strategy == 0 {
    self.frame_number * Int64::from_int(self.block_size)
  } else {
    self.frame_number
  }
}

/// The fixed block size for block-size codes 1..=5 and 8..=15, or `-1` for a
/// reserved / special code.
fn fixed_block_size(code : Int) -> Int {
  match code {
    1 => 192
    2 => 576
    3 => 1152
    4 => 2304
    5 => 4608
    8 => 256
    9 => 512
    10 => 1024
    11 => 2048
    12 => 4096
    13 => 8192
    14 => 16384
    15 => 32768
    _ => -1
  }
}

/// The fixed sample rate for sample-rate codes 1..=11, or `-1` for a reserved /
/// special code.
fn fixed_sample_rate(code : Int) -> Int {
  match code {
    1 => 88200
    2 => 176400
    3 => 192000
    4 => 8000
    5 => 16000
    6 => 22050
    7 => 24000
    8 => 32000
    9 => 44100
    10 => 48000
    11 => 96000
    _ => -1
  }
}

/// Channel count and channel-assignment code for a 4-bit channel code.
fn channel_info(code : Int) -> (Int, Int) raise DecodeError {
  if code <= 7 {
    (code + 1, code)
  } else if code == 8 || code == 9 || code == 10 {
    (2, code)
  } else {
    raise InvalidFrameHeader
  }
}

/// Bits per sample for a 3-bit sample-size code (excluding `0` = from stream).
fn fixed_sample_size(code : Int) -> Int raise DecodeError {
  match code {
    1 => 8
    2 => 12
    4 => 16
    5 => 20
    6 => 24
    7 => 32
    _ => raise InvalidFrameHeader
  }
}

/// Parse a frame header from a byte-aligned reader, verify its CRC-8, and
/// return the decoded header plus the reader positioned at the first subframe.
pub fn BitReader::read_frame_header(self : BitReader, info : StreamInfo) -> (FrameHeader, BitReader) raise DecodeError {
  let start_byte = self.pos() / 8
  let (sync, r1) = self.read_bits(14)
  if sync != 0x3FFE {
    raise InvalidFrameSync
  }
  let (_, r2) = r1.read_bit()
  let (blocking, r3) = r2.read_bit()
  let (bs_code, r4) = r3.read_bits(4)
  let (sr_code, r5) = r4.read_bits(4)
  let (ch_code, r6) = r5.read_bits(4)
  let (bps_code, r7) = r6.read_bits(3)
  let (_, r8) = r7.read_bit()
  let (frame_number, r9) = r8.read_utf8_number()

  let (block_size, r10) = if bs_code == 6 {
    let (v, rr) = r9.read_byte()
    (v + 1, rr)
  } else if bs_code == 7 {
    let (v, rr) = r9.read_u16()
    (v + 1, rr)
  } else {
    let v = fixed_block_size(bs_code)
    if v < 0 {
      raise InvalidFrameHeader
    }
    (v, r9)
  }

  let (sample_rate, r11) = if sr_code == 0 {
    (info.sample_rate, r10)
  } else if sr_code == 12 {
    let (v, rr) = r10.read_byte()
    (v * 1000, rr)
  } else if sr_code == 13 {
    let (v, rr) = r10.read_u16()
    (v, rr)
  } else if sr_code == 14 {
    let (v, rr) = r10.read_u16()
    (v * 10, rr)
  } else {
    let v = fixed_sample_rate(sr_code)
    if v < 0 {
      raise InvalidFrameHeader
    }
    (v, r10)
  }

  let (channels, channel_assignment) = channel_info(ch_code)
  let bits_per_sample = if bps_code == 0 {
    info.bits_per_sample
  } else {
    fixed_sample_size(bps_code)
  }

  let crc_byte = r11.pos() / 8
  let (stored_crc, r12) = r11.read_byte()
  let expected = crc8_range(self.data(), start_byte, crc_byte, 0x07, 0)
  if expected != stored_crc {
    raise HeaderCrcMismatch
  }

  (
    FrameHeader::new(blocking, block_size, sample_rate, channels, channel_assignment, bits_per_sample, frame_number),
    r12,
  )
}
