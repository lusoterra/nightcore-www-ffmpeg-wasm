# Strict-minimum audio-only ffmpeg configure flags for the wasm core.
# Everything a nightcore needs, nothing else:
#   in:  mp3/flac/m4a-aac/alac/ogg-vorbis/opus/wav/aiff (+ cover jpg/png)
#   out: opus / mp3 / flac / alac
#   dsp: asetrate + aresample=soxr ("sox" resampling) + rubberband pitch
# Exotics (ape/wv/tta/wma/ac3/dts/mpc) are one line away in git history
# if anyone ever asks; re-add the demuxer+decoder pair and rebuild.
# Emits CONFIGURE_FLAGS array. Sourced by build.sh AFTER emsdk env +
# EM_PKG_CONFIG_PATH are set (build.sh appends --cc/--cxx/--ar/paths).

CONFIGURE_FLAGS=(
  --target-os=none --arch=x86_32 --enable-cross-compile
  --disable-x86asm --disable-inline-asm --disable-stripping
  --disable-programs --disable-doc --disable-debug
  --disable-network --disable-autodetect --disable-runtime-cpudetect
  --disable-pthreads --disable-w32threads --disable-os2threads
  --disable-everything
  --enable-gpl
  --enable-libmp3lame --enable-libopus --enable-librubberband
  --enable-libsoxr
  --enable-zlib
  --pkg-config-flags=--static

  # protocols / demuxers / muxers
  --enable-protocol=file
  --enable-demuxer=wav,aiff,flac,mp3,ogg,opus,aac,mov,mp4,image2
  --enable-muxer=wav,flac,mp3,ogg,opus,mp4,mov
  --enable-parser=flac,mpegaudio,opus,vorbis,aac
  --enable-bsf=aac_adtstoasc

  # decoders (native; lame/opus libs are encode-side)
  --enable-decoder=pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,pcm_u8,flac,mp3float,aac,alac,opus,vorbis,mjpeg,png
  # encoders: site outputs only, plus float PCM for the pitch
  # anti-clip temp (rubberband can overshoot 0dBFS; the float temp
  # preserves overs for measurement, exactly like the CLI tame step)
  --enable-encoder=flac,libmp3lame,libopus,alac,pcm_f32le
  # filters: nightcore chain only (+atempo fallback when rubberband is off).
  # aformat+anull are mandatory: ffmpeg auto-inserts them to negotiate
  # formats between filters and encoders -- without them EVERY graph
  # fails with "not connected". volume applies the measured anti-clip
  # trim on hot pitch renders (CLI tame_hot_wav parity).
  --enable-filter=aresample,asetrate,atempo,rubberband,aformat,anull,volume
)
