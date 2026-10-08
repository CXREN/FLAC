///|
/// Stereo channel decorrelation (RFC 9639, section 9.2.8). Stereo FLAC streams
/// may store a left/side, right/side or mid/side pair instead of two independent
/// channels; this module turns the decoded pair back into left and right.

/// Convert decoded planar channels into standard channel order.
///
/// For the independent channel assignments (0..=7) the input is returned
/// unchanged. For the stereo assignments 8 (left+side), 9 (right+side) and
/// 10 (mid+side) the two decoded channels are combined into `[left, right]`.
pub fn decorrelate(channels : Array[Array[Int]], assignment : Int) -> Array[Array[Int]] {
  if assignment < 8 {
    return channels
  }
  let n = channels[0].length()
  let out_left = Array::make(n, 0)
  let out_right = Array::make(n, 0)
  if assignment == 8 {
    // left + side: channel 0 is left, channel 1 is side.
    for i in 0..<n {
      out_left.set(i, channels[0][i])
      out_right.set(i, channels[0][i] - channels[1][i])
    }
  } else if assignment == 9 {
    // right + side: channel 0 is side, channel 1 is right.
    for i in 0..<n {
      out_left.set(i, channels[0][i] + channels[1][i])
      out_right.set(i, channels[1][i])
    }
  } else {
    // mid + side: channel 0 is mid, channel 1 is side.
    for i in 0..<n {
      let mid = channels[0][i]
      let side = channels[1][i]
      out_left.set(i, mid + ((side + 1) >> 1))
      out_right.set(i, mid - (side >> 1))
    }
  }
  [out_left, out_right]
}
