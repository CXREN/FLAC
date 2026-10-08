///|
/// Subframe decoding: the per-channel blocks that carry a frame's audio.
///
/// Four subframe types are supported — CONSTANT, VERBATIM, FIXED and LPC.
/// Each starts with an 8-bit header (a zero bit, a 6-bit type code, and a
/// wasted-bits flag) and, for the predictive types, runs a predictor over a
/// Rice-coded residual.

/// Decode one subframe of `block_size` samples at `bits_per_sample` bits per
/// sample, returning the signed samples and the reader past the subframe.
pub fn BitReader::read_subframe(
  self : BitReader,
  block_size : Int,
  bits_per_sample : Int
) -> (Array[Int], BitReader) raise DecodeError {
  let (header, r0) = self.read_byte()
  if (header & 0x80) != 0 {
    raise InvalidSubframe
  }
  let type_code = (header >> 1) & 0x3F
  let mut r = r0
  let mut wasted_bits = 0
  if (header & 1) == 1 {
    let (w, r1) = r.read_unary()
    wasted_bits = w + 1
    r = r1
  }
  let bps = bits_per_sample - wasted_bits
  if bps < 1 {
    raise InvalidSubframe
  }
  let (raw, r2) = if type_code == 0 {
    read_constant(r, block_size, bps)
  } else if type_code == 1 {
    read_verbatim(r, block_size, bps)
  } else if type_code >= 8 && type_code <= 12 {
    read_fixed(r, block_size, bps, type_code - 8)
  } else if type_code >= 32 {
    read_lpc(r, block_size, bps, type_code - 31)
  } else {
    raise InvalidSubframe
  }
  if wasted_bits > 0 {
    let shifted = Array::make(raw.length(), 0)
    for i in 0..<raw.length() {
      shifted.set(i, raw[i] << wasted_bits)
    }
    (shifted, r2)
  } else {
    (raw, r2)
  }
}

/// CONSTANT: one sample repeated across the whole block.
fn read_constant(r : BitReader, block_size : Int, bps : Int) -> (Array[Int], BitReader) raise DecodeError {
  let (v, r2) = r.read_signed(bps)
  (Array::make(block_size, v), r2)
}

/// VERBATIM: `block_size` samples stored as-is.
fn read_verbatim(r : BitReader, block_size : Int, bps : Int) -> (Array[Int], BitReader) raise DecodeError {
  let samples = Array::make(block_size, 0)
  let mut rr = r
  for i in 0..<block_size {
    let (v, r2) = rr.read_signed(bps)
    samples.set(i, v)
    rr = r2
  }
  (samples, rr)
}

/// FIXED: `order` warm-up samples followed by a residual restored with a
/// fixed predictor.
fn read_fixed(r : BitReader, block_size : Int, bps : Int, order : Int) -> (Array[Int], BitReader) raise DecodeError {
  let samples = Array::make(block_size, 0)
  let mut rr = r
  for i in 0..<order {
    let (v, r2) = rr.read_signed(bps)
    samples.set(i, v)
    rr = r2
  }
  let (residual, r3) = rr.read_residual(block_size, order)
  restore_fixed(order, samples, residual)
  (samples, r3)
}

/// LPC: warm-up samples, predictor precision / shift / coefficients, then a
/// residual restored with the linear predictor.
fn read_lpc(r : BitReader, block_size : Int, bps : Int, order : Int) -> (Array[Int], BitReader) raise DecodeError {
  let samples = Array::make(block_size, 0)
  let mut rr = r
  for i in 0..<order {
    let (v, r2) = rr.read_signed(bps)
    samples.set(i, v)
    rr = r2
  }
  let (precision_raw, r2) = rr.read_bits(4)
  if precision_raw == 15 {
    raise InvalidSubframe
  }
  let precision = precision_raw + 1
  let (shift, r3) = r2.read_signed(5)
  if shift < 0 {
    raise InvalidSubframe
  }
  let coeffs = Array::make(order, 0)
  let mut r4 = r3
  for i in 0..<order {
    let (c, r5) = r4.read_signed(precision)
    coeffs.set(i, c)
    r4 = r5
  }
  let (residual, r6) = r4.read_residual(block_size, order)
  restore_lpc(order, shift, coeffs, samples, residual)
  (samples, r6)
}

/// In-place fixed-predictor reconstruction. `samples` holds the warm-up values
/// in its first `order` slots; the residual fills the rest.
fn restore_fixed(order : Int, samples : Array[Int], residual : Array[Int]) -> Unit {
  let n = samples.length()
  for i in order..<n {
    let pred = match order {
      0 => 0
      1 => samples[i - 1]
      2 => 2 * samples[i - 1] - samples[i - 2]
      3 => 3 * samples[i - 1] - 3 * samples[i - 2] + samples[i - 3]
      4 => 4 * samples[i - 1] - 6 * samples[i - 2] + 4 * samples[i - 3] - samples[i - 4]
      _ => 0
    }
    samples.set(i, residual[i - order] + pred)
  }
}

/// In-place linear-predictor reconstruction. Coefficients are stored in reverse
/// chronological order, so `coeffs[j]` multiplies the sample `j + 1` positions
/// back.
fn restore_lpc(order : Int, shift : Int, coeffs : Array[Int], samples : Array[Int], residual : Array[Int]) -> Unit {
  let n = samples.length()
  for i in order..<n {
    let mut sum = 0
    for j in 0..<order {
      sum = sum + coeffs[j] * samples[i - 1 - j]
    }
    let pred = sum >> shift
    samples.set(i, residual[i - order] + pred)
  }
}
