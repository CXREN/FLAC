///|
/// Partitioned Rice residual decoding (RFC 9639, section 9.2.7).
///
/// A residual block is the sequence of prediction errors left after the
/// predictor has run. It is split into `2^order` partitions; each partition
/// is either a run of Rice codes or, when the Rice parameter equals the all-ones
/// escape code, a run of raw two's-complement samples.

/// Decode one partition of `count` Rice-coded residuals with a fixed Rice
/// parameter, returning the partition reader and the signed residuals.
fn BitReader::read_rice_partition(
  self : BitReader,
  count : Int,
  param : Int
) -> (BitReader, Array[Int]) raise DecodeError {
  let samples = Array::make(count, 0)
  let mut r = self
  for i in 0..<count {
    let (q, r1) = r.read_unary()
    let (remainder, r2) = if param == 0 { (0, r1) } else { r1.read_bits(param) }
    // Folded value: quotient in unary, remainder in `param` bits, MSB first.
    let folded = (q << param) | remainder
    // Zigzag decode: even -> folded / 2, odd -> -(folded / 2) - 1.
    let signed = if (folded & 1) == 0 { folded >> 1 } else { -(folded >> 1) - 1 }
    samples.set(i, signed)
    r = r2
  }
  (r, samples)
}

/// Decode a complete residual block of `block_size - predictor_order` samples.
///
/// The reader must be positioned at the 2-bit coding method. On success the
/// returned reader is positioned just past the last residual sample.
pub fn BitReader::read_residual(
  self : BitReader,
  block_size : Int,
  predictor_order : Int
) -> (Array[Int], BitReader) raise DecodeError {
  let (rice_method, r1) = self.read_bits(2)
  let param_bits = if rice_method == 0 {
    4
  } else if rice_method == 1 {
    5
  } else {
    raise InvalidResidual
  }
  let (partition_order, r2) = r1.read_bits(4)
  let num_partitions = 1 << partition_order
  let partition_samples = block_size >> partition_order
  if num_partitions * partition_samples != block_size {
    raise InvalidResidual
  }
  if partition_samples <= predictor_order {
    raise InvalidResidual
  }
  let escape = (1 << param_bits) - 1
  let total = block_size - predictor_order
  let samples = Array::make(total, 0)
  let mut r = r2
  let mut out = 0
  for p in 0..<num_partitions {
    // The first partition is shortened by the predictor order.
    let count = if p == 0 { partition_samples - predictor_order } else { partition_samples }
    let (param, r3) = r.read_bits(param_bits)
    if param == escape {
      // Escaped partition: 5 bits give the raw sample width, then `count`
      // samples stored directly as signed two's-complement.
      let (bits, r4) = r3.read_bits(5)
      r = r4
      for _ in 0..<count {
        let (v, r5) = if bits == 0 { (0, r) } else { r.read_signed(bits) }
        samples.set(out, v)
        out = out + 1
        r = r5
      }
    } else {
      let (rr, partition) = r3.read_rice_partition(count, param)
      for v in partition {
        samples.set(out, v)
        out = out + 1
      }
      r = rr
    }
  }
  (samples, r)
}
