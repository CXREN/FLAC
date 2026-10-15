///|
/// WAV (RIFF/WAVE) output for decoded PCM. The decoder produces interleaved
/// signed samples; this module wraps them in a standard little-endian PCM WAV
/// container so a decoded stream can be written to disk or played back with
/// any audio tool.

/// The number of bytes each sample occupies in the payload: the bit depth
/// rounded up to a whole byte.
fn bytes_per_sample(bits_per_sample : Int) -> Int {
  (bits_per_sample + 7) / 8
}

/// Write `value` into `out` as a little-endian integer of `nbytes` bytes,
/// starting at byte `pos`.
fn write_le(out : Array[Byte], pos : Int, value : Int, nbytes : Int) -> Unit {
  for i in 0..<nbytes {
    out.set(pos + i, ((value >> (8 * i)) & 0xFF).to_byte())
  }
}

/// Write a four-byte ASCII tag ("RIFF", "WAVE", "fmt ", "data") at `pos`.
fn write_tag(out : Array[Byte], pos : Int, tag : Bytes) -> Unit {
  for i in 0..<tag.length() {
    out.set(pos + i, tag[i])
  }
}

/// Encode decoded PCM as a standard PCM WAV. 16/24/32-bit samples are stored
/// as little-endian two's complement; 8-bit samples use the WAV unsigned
/// convention (a +128 offset).
pub fn Pcm::to_wav(self : Pcm) -> Bytes {
  let bps = bytes_per_sample(self.bits_per_sample)
  let data_size = self.samples.length() * bps
  let total = 44 + data_size
  let out = Array::make(total, b'\x00')
  write_tag(out, 0, b"RIFF")
  write_le(out, 4, total - 8, 4)
  write_tag(out, 8, b"WAVE")
  write_tag(out, 12, b"fmt ")
  write_le(out, 16, 16, 4)
  write_le(out, 20, 1, 2)
  write_le(out, 22, self.channels, 2)
  write_le(out, 24, self.sample_rate, 4)
  write_le(out, 28, self.sample_rate * self.channels * bps, 4)
  write_le(out, 32, self.channels * bps, 2)
  write_le(out, 34, self.bits_per_sample, 2)
  write_tag(out, 36, b"data")
  write_le(out, 40, data_size, 4)
  for i in 0..<self.samples.length() {
    let s = self.samples[i]
    if self.bits_per_sample == 8 {
      out.set(44 + i, ((s + 128) & 0xFF).to_byte())
    } else {
      for j in 0..<bps {
        out.set(44 + i * bps + j, ((s >> (8 * j)) & 0xFF).to_byte())
      }
    }
  }
  Bytes::from_array(out)
}
