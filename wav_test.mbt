///|
/// WAV output: the decoded PCM wrapped in a RIFF/WAVE container. The 44-byte
/// header is checked byte-for-byte and the interleaved sample payload follows.

test "wav header fields for 16-bit stereo" {
  let pcm = @flac.Pcm::new(44100, 2, 16, [100, -100, 200, -200])
  let wav = pcm.to_wav()
  assert_true(wav.length() == 44 + 8)
  // "RIFF"
  assert_true(wav[0] == b'R' && wav[1] == b'I' && wav[2] == b'F' && wav[3] == b'F')
  // chunk size = total - 8 = 44
  assert_true(wav[4].to_int() == 44 && wav[5].to_int() == 0 && wav[6].to_int() == 0 && wav[7].to_int() == 0)
  // "WAVE" and "fmt "
  assert_true(wav[8] == b'W' && wav[9] == b'A' && wav[10] == b'V' && wav[11] == b'E')
  assert_true(wav[12] == b'f' && wav[13] == b'm' && wav[14] == b't' && wav[15] == b' ')
  // fmt chunk size = 16, audio format = 1 (PCM)
  assert_true(wav[16].to_int() == 16)
  assert_true(wav[20].to_int() == 1 && wav[21].to_int() == 0)
  // channels = 2
  assert_true(wav[22].to_int() == 2 && wav[23].to_int() == 0)
  // sample rate 44100 = 0xAC44 -> little-endian 44 AC
  assert_true(wav[24].to_int() == 0x44 && wav[25].to_int() == 0xAC)
  // byte rate = 44100 * 2 * 2 = 176400 = 0x02B110 -> 10 B1 02 00
  assert_true(wav[28].to_int() == 0x10 && wav[29].to_int() == 0xB1 && wav[30].to_int() == 0x02 && wav[31].to_int() == 0)
  // block align = 4, bits per sample = 16
  assert_true(wav[32].to_int() == 4 && wav[33].to_int() == 0)
  assert_true(wav[34].to_int() == 16 && wav[35].to_int() == 0)
  // "data", data size = 8
  assert_true(wav[36] == b'd' && wav[37] == b'a' && wav[38] == b't' && wav[39] == b'a')
  assert_true(wav[40].to_int() == 8)
  // payload: 100, -100, 200, -200 as 16-bit little-endian
  assert_true(wav[44].to_int() == 0x64 && wav[45].to_int() == 0x00)
  assert_true(wav[46].to_int() == 0x9C && wav[47].to_int() == 0xFF)
  assert_true(wav[48].to_int() == 0xC8 && wav[49].to_int() == 0x00)
  assert_true(wav[50].to_int() == 0x38 && wav[51].to_int() == 0xFF)
}

test "wav 8-bit samples use the unsigned +128 offset" {
  let pcm = @flac.Pcm::new(8000, 1, 8, [0, 127, -128])
  let wav = pcm.to_wav()
  assert_true(wav.length() == 44 + 3)
  assert_true(wav[32].to_int() == 1 && wav[34].to_int() == 8)
  assert_true(wav[44].to_int() == 128)
  assert_true(wav[45].to_int() == 255)
  assert_true(wav[46].to_int() == 0)
}

test "wav 24-bit samples are little-endian" {
  let pcm = @flac.Pcm::new(48000, 1, 24, [1, -1])
  let wav = pcm.to_wav()
  assert_true(wav.length() == 44 + 6)
  assert_true(wav[32].to_int() == 3 && wav[34].to_int() == 24)
  // 1 -> 01 00 00 ; -1 -> FF FF FF
  assert_true(wav[44].to_int() == 0x01 && wav[45].to_int() == 0x00 && wav[46].to_int() == 0x00)
  assert_true(wav[47].to_int() == 0xFF && wav[48].to_int() == 0xFF && wav[49].to_int() == 0xFF)
}
