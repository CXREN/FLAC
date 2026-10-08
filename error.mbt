///|
/// Errors raised while reading or decoding a FLAC stream.
///
/// Every parsing function in this package raises `DecodeError`; callers can
/// either let it propagate or convert it to a `Result` with
/// `try ... catch { e => Err(e) }`.

pub(all) suberror DecodeError {
  /// The input ended before a complete value could be read.
  Truncated

  /// A `read_bits` call asked for a width outside `0..=32`.
  InvalidBitCount

  /// The four-byte marker at the start of the stream is not `fLaC`.
  NotFlac

  /// A metadata block was malformed (bad length, bad STREAMINFO, ...).
  InvalidMetadata

  /// The 14-bit frame sync code `0x3FFE` was not found.
  InvalidFrameSync

  /// A reserved block-size / sample-rate / sample-size code was used.
  InvalidFrameHeader

  /// The frame-header CRC-8 does not match.
  HeaderCrcMismatch

  /// The frame-body CRC-16 does not match.
  FrameCrcMismatch

  /// The residual coding inside a subframe was malformed.
  InvalidResidual

  /// The subframe header was malformed (bad first bit, reserved type code, ...).
  InvalidSubframe

  /// A well-formed but not-yet-supported FLAC feature was encountered.
  Unsupported(String)
}
