# flac

A pure-MoonBit decoder for [FLAC](https://xiph.org/flac/format.html) (Free
Lossless Audio Codec, RFC 9639). No native bindings, no FFI, no runtime
dependencies beyond the MoonBit standard library — the whole pipeline compiles
to WASM and runs wherever MoonBit does.

## What it does

`flac` turns a FLAC byte stream into interleaved signed PCM samples:

- **Metadata** — the `fLaC` marker and the metadata-block chain, starting with
  `STREAMINFO` (sample rate, channels, bit depth, total samples, MD5).
- **Frames** — the 14-bit sync code, block-size / sample-rate / channel /
  sample-size codes, the UTF-8 coded frame number, and the CRC-8 / CRC-16
  guards.
- **Subframes** — CONSTANT, VERBATIM, FIXED (orders 0–4) and LPC (orders
  1–32), with partitioned Rice residuals including escaped partitions and
  wasted-bits handling.
- **Stereo** — left+side, right+side and mid+side decorrelation back into
  left/right.
- **Tags & artwork** — VORBIS_COMMENT, PICTURE, SEEKTABLE, APPLICATION and
  PADDING blocks decoded into typed values.
- **Output & integrity** — WAV (RIFF/WAVE) container output, and an MD5
  implementation that verifies a decoded stream against its `STREAMINFO`
  signature (`@flac.verify`).

## Modules

| File | Purpose |
| --- | --- |
| `bitreader.mbt` | A forward-only, big-endian bit cursor over `Bytes`. |
| `crc.mbt` | CRC-8 and CRC-16 (MSB-first), including the two FLAC polynomials. |
| `error.mbt` | The `DecodeError` type raised by every parsing entry point. |
| `streaminfo.mbt` | The 34-byte `STREAMINFO` block. |
| `metadata.mbt` | The `fLaC` marker and typed metadata-block chain. |
| `frame.mbt` | Frame-header parsing with CRC-8 verification. |
| `residual.mbt` | Partitioned Rice residual decoding. |
| `subframe.mbt` | CONSTANT / VERBATIM / FIXED / LPC subframe decoding. |
| `decorrelate.mbt` | Stereo channel decorrelation. |
| `decode.mbt` | Whole-frame and whole-stream decoding to interleaved PCM. |
| `wav.mbt` | RIFF/WAVE container output from decoded PCM. |
| `md5.mbt` | MD5 digest (RFC 1321) with hex rendering. |

## Usage

Decode a whole stream:

```moonbit
let pcm : @flac.Pcm = @flac.decode(flac_bytes)
// pcm.sample_rate, pcm.channels, pcm.bits_per_sample, pcm.samples
```

`pcm.samples` is a flat `Array[Int]` of interleaved samples
(`[L0, R0, L1, R1, …]` for stereo). For finer control, `@flac.decode_frame`
decodes one frame at a time, and the per-module entry points
(`@flac.parse_metadata`, `@flac.BitReader::read_frame_header`, …) expose each
stage individually.

Wrap the samples in a WAV container:

```moonbit
let wav_bytes : Bytes = pcm.to_wav()
```

Verify a stream end-to-end against the MD5 signature stored in its
`STREAMINFO` block:

```moonbit
let ok : Bool = @flac.verify(flac_bytes)
```

## Demo

Run the included demo to decode two embedded streams (a mono verbatim one and
a mid+side stereo one) and print their properties and first samples:

```
moon run cmd/main
```

## Tests

The test suite covers unit vectors for every stage (bit cursor, CRC,
`STREAMINFO`, each metadata block type, subframes, residuals, WAV, MD5) plus
end-to-end decoding of real FLAC files produced by the reference
libsndfile/libFLAC encoder — decoded sample-by-sample against the encoder's
own output and verified against the `STREAMINFO` MD5 signature.

## License

Apache-2.0
