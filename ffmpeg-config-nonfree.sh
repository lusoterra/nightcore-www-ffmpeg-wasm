# Non-free variant: adds FDK-AAC (libfdk_aac) encoder.
# FDK-AAC's license is incompatible with FFmpeg's GPL, so this build
# requires --enable-nonfree and produces a BINARY YOU MAY NOT
# REDISTRIBUTE. Keep it for personal/local use only.
# Sourced by build.sh when NONFREE=1.
CONFIGURE_FLAGS=(
  --target-os=none --arch=x86_32 --enable-cross-compile
  --disable-x86asm --disable-inline-asm --disable-stripping
  --disable-programs --disable-doc --disable-debug
  --disable-network --disable-autodetect --disable-runtime-cpudetect
  --disable-pthreads --disable-w32threads --disable-os2threads
  --disable-everything
  --enable-gpl
  --enable-nonfree
  --enable-libmp3lame --enable-libopus --enable-librubberband
  --enable-libsoxr --enable-libfdk-aac
  --enable-zlib
  --pkg-config-flags=--static

  --enable-protocol=file
  --enable-demuxer=wav,aiff,flac,mp3,ogg,opus,aac,mov,mp4,image2
  --enable-muxer=wav,flac,mp3,ogg,opus,mp4,mov
  --enable-parser=flac,mpegaudio,opus,vorbis,aac
  --enable-bsf=aac_adtstoasc

  --enable-decoder=pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,pcm_u8,flac,mp3float,aac,alac,opus,vorbis,mjpeg,png
  --enable-encoder=flac,libmp3lame,libopus,alac,pcm_f32le,libfdk_aac
  --enable-filter=aresample,asetrate,atempo,rubberband,aformat,anull,volume
)