#!/bin/bash
# Custom ffmpeg-core.wasm (+js glue) for nightcore-www.
# Stock @ffmpeg/core lacks the rubberband filter; this adds exactly that
# (--enable-librubberband) plus the SoX resampler (--enable-libsoxr,
# selected via aresample ...:resampler=soxr).
# Single-threaded: no COOP/COEP headers needed on the server.
# Idempotent: finished steps are marked in prefix/ and skipped on rerun.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source versions.env

ROOT="$PWD"
SRC="$ROOT/src"
PREFIX="$ROOT/prefix"
OUT="${CORE_OUT_DIR:-$ROOT/build}"
JOBS="$(nproc 2>/dev/null || echo 4)"
mkdir -p "$SRC" "$PREFIX" "$OUT"

for t in python3 cmake make pkg-config curl git autoreconf emcc; do :; done # emcc comes from emsdk below
for t in python3 cmake make pkg-config curl git autoreconf; do
  command -v "$t" >/dev/null || { echo "error: missing build tool: $t"; exit 1; }
done

if [ ! -d emsdk ]; then
  git clone https://github.com/emscripten-core/emsdk.git
fi
(cd emsdk && ./emsdk install "$EMSDK_VERSION" && ./emsdk activate "$EMSDK_VERSION")
# shellcheck disable=SC1091
source ./emsdk/emsdk_env.sh >/dev/null

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
# emconfigure scrubs PKG_CONFIG_PATH; it reads EM_PKG_CONFIG_PATH instead.
export EM_PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
# Relocatable prefix: installed .pc files bake absolute paths, so a
# moved checkout breaks pkg-config discovery. Rewrite them every run.
if [ -d "$PREFIX/lib/pkgconfig" ]; then
    sed -i "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX"/lib/pkgconfig/*.pc 2>/dev/null || true
fi
# -pthread-free zone: FFmpeg 5.1 predates the threaded transcode
# scheduler (added in 6.x), so --disable-pthreads yields a fully working
# single-threaded CLI -- exactly what upstream's own wasm core ships.
# No SharedArrayBuffer, no COOP/COEP headers anywhere.
export CFLAGS="-O3 -I$PREFIX/include"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-O3 -L$PREFIX/lib"

mark() { touch "$PREFIX/.built-$1"; }
done_mark() { [ -f "$PREFIX/.built-$1" ]; }

echo "==> zlib $ZLIB_VERSION"
done_mark zlib || {
  curl -fSL "https://github.com/madler/zlib/releases/download/v$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz" | tar -xz -C "$SRC"
  (cd "$SRC/zlib-$ZLIB_VERSION" && emcmake cmake -Bbuild -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF >/dev/null && cmake --build build -j"$JOBS" >/dev/null && cmake --install build >/dev/null)
  rm -f "$PREFIX"/lib/libz.so* # static-only prefix: a stray .so shadows libz.a and breaks tests
  mark zlib
}

autoconf_lib() { # name version url [extra-configure-args...]
  local name="$1" version="$2" url="$3"; shift 3
  done_mark "$name" || {
    echo "==> $name $version"
    # Nuke any previous tree: stale .o files from other flag sets would
    # otherwise survive (make can't see CFLAGS changes) and link into
    # a Frankenstein library.
    rm -rf "$SRC/"*"$name-$version"*
    curl -fSL "$url" | tar -xz -C "$SRC"
    # shellcheck disable=SC2155
    # (tarballs don't always extract to $name-$version, e.g. libogg)
    local dir
    dir="$(ls -d "$SRC/"*"$name-$version"* | head -1)"
    (cd "$dir" && emconfigure ./configure --prefix="$PREFIX" --host=i686-linux --disable-shared --disable-dependency-tracking "$@" >/dev/null && emmake make -j"$JOBS" >/dev/null && emmake make install >/dev/null)
    mark "$name"
  }
}

autoconf_lib lame "$LAME_VERSION" \
  "https://downloads.sourceforge.net/project/lame/lame/$LAME_VERSION/lame-$LAME_VERSION.tar.gz" \
  --host=i686-linux --disable-frontend --disable-analyzer-hooks --disable-gtktest

autoconf_lib ogg "$OGG_VERSION" \
  "https://downloads.xiph.org/releases/ogg/libogg-$OGG_VERSION.tar.gz"

# NOTE: --enable-fixed-point is load-bearing, not a preference: the
# float CELT stereo path traps under wasm (verified: stock float opus
# traps identically, fixed-point encodes clean). Same code path as
# billions of phones; transparent at 128k sharing bitrates.
autoconf_lib opus "$OPUS_VERSION" \
  "https://downloads.xiph.org/releases/opus/opus-$OPUS_VERSION.tar.gz" \
  --disable-asm --disable-rtcd --disable-doc --disable-extra-programs --disable-stack-protector --enable-fixed-point --enable-fixed-point

# SoX Resampler Library (libsoxr): the "sox" resampling engine behind
# aresample ...:resampler=soxr (every resample/prescale/settle step).
# Needs bridge/soxr-wasm-sigmatch.patch: upstream's DFT callback
# tables call 0/3-arg functions through 1/4-arg casts -- legal C, but
# wasm call_indirect type-checks every signature and traps. The patch
# adds exact-arity shims (behaviour unchanged). Scalar code paths:
# soxr's cmake SIMD probe fails under emcc, so no vector code ships.
# No threads (-pthread-free core), no LSR bindings, no tests/examples.
echo "==> soxr $SOXR_VERSION"
done_mark soxr || {
  if [ ! -f "$SRC/soxr-$SOXR_VERSION-Source/.patched-sigmatch" ]; then
    rm -rf "$SRC/soxr-$SOXR_VERSION-Source"
    curl -fSL "https://downloads.sourceforge.net/project/soxr/soxr-$SOXR_VERSION-Source.tar.xz" | tar -xJ -C "$SRC"
    (cd "$SRC/soxr-$SOXR_VERSION-Source" && patch -p1 --forward < "$ROOT/bridge/soxr-wasm-sigmatch.patch") \
      && touch "$SRC/soxr-$SOXR_VERSION-Source/.patched-sigmatch"
  fi
  rm -rf "$SRC/soxr-$SOXR_VERSION-Source/build" # stale native/vendor-era dir
  (cd "$SRC" && emcmake cmake -S "soxr-$SOXR_VERSION-Source" -B "soxr-$SOXR_VERSION-Source/build-wasm" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF \
    -DWITH_OPENMP=OFF -DWITH_LSR_BINDINGS=OFF -DWITH_DEV_TRACE=OFF -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_C_FLAGS="-O3" >/dev/null \
    && emmake make -C "soxr-$SOXR_VERSION-Source/build-wasm" -j"$JOBS" >/dev/null \
    && emmake make -C "soxr-$SOXR_VERSION-Source/build-wasm" install >/dev/null)
  mark soxr
}

echo "==> rubberband $RUBBERBAND_VERSION (single-file amalgamation, no meson needed)"
done_mark rubberband || {
  curl -fSL "https://breakfastquay.com/files/releases/rubberband-$RUBBERBAND_VERSION.tar.bz2" | tar -xj -C "$SRC"
  (cd "$SRC/rubberband-$RUBBERBAND_VERSION" && emcc $CFLAGS -fno-exceptions -fno-rtti -DNO_EXCEPTIONS -I. -c single/RubberBandSingle.cpp -o librubberband.o && emar rcs "$PREFIX/lib/librubberband.a" librubberband.o)
  mkdir -p "$PREFIX/include/rubberband"
  cp "$SRC/rubberband-$RUBBERBAND_VERSION"/rubberband/*.h "$PREFIX/include/rubberband/"
  cat > "$PREFIX/lib/pkgconfig/rubberband.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: rubberband
Description: Rubber Band audio time-stretching and pitch-shifting
Version: $RUBBERBAND_VERSION
Libs: -L\${libdir} -lrubberband -lc++ -lc++abi
Libs.private: -lc++ -lc++abi -lm
Cflags: -I\${includedir}
EOF
  mark rubberband
}

if [ "${NONFREE:-0}" = "1" ]; then
  echo "==> fdk-aac (nonfree)"
  done_mark fdk-aac || {
    rm -rf "$SRC/fdk-aac-2.0.2"*
    curl -fSL "https://github.com/mstorsjo/fdk-aac/archive/v2.0.2.tar.gz" | tar -xz -C "$SRC"
    (cd "$SRC/fdk-aac-2.0.2" && autoreconf -fiv >/dev/null 2>&1; emconfigure ./configure --prefix="$PREFIX" --host=i686-linux --disable-shared --disable-dependency-tracking >/dev/null && emmake make -j"$JOBS" >/dev/null && emmake make install >/dev/null)
    mark fdk-aac
  }
fi

echo "==> ffmpeg $FFMPEG_VERSION"
[ -d "$SRC/ffmpeg" ] || git clone --depth 1 --branch "n$FFMPEG_VERSION" https://github.com/FFmpeg/FFmpeg.git "$SRC/ffmpeg"
if [ ! -f "$SRC/ffmpeg/.patched-progress" ]; then
  (cd "$SRC/ffmpeg" && patch -p1 --forward < "$ROOT/bridge/print_report-progress.patch") \
    && touch "$SRC/ffmpeg/.patched-progress"
fi
if [ ! -f "$SRC/ffmpeg/.patched-rerun" ]; then
  (cd "$SRC/ffmpeg" && patch -p1 --forward < "$ROOT/bridge/ffmpeg-rerun-reset.patch") \
    && touch "$SRC/ffmpeg/.patched-rerun"
fi
if [ ! -f "$SRC/ffmpeg/.patched-rb-offline" ]; then
  (cd "$SRC/ffmpeg" && patch -p1 --forward < "$ROOT/bridge/af-rubberband-cli-parity.patch") \
    && touch "$SRC/ffmpeg/.patched-rb-offline"
fi
# shellcheck disable=SC1091
if [ "${NONFREE:-0}" = "1" ]; then
  source ffmpeg-config-nonfree.sh # sets CONFIGURE_FLAGS (non-redistributable)
else
  source ffmpeg-config.sh # sets CONFIGURE_FLAGS
fi
(cd "$SRC/ffmpeg" && emconfigure ./configure "${CONFIGURE_FLAGS[@]}" \
  --cc=emcc --cxx=em++ --ar=emar --ranlib=emranlib --nm=emnm \
  --extra-cflags="-I$PREFIX/include" --extra-ldflags="-L$PREFIX/lib" \
  --prefix="$PREFIX" >/dev/null)
(cd "$SRC/ffmpeg" && emmake make -j"$JOBS" >/dev/null)

echo "==> link ffmpeg-core.js/wasm"
mkdir -p "$OUT"
# NOTE: 2GB MAXIMUM_MEMORY below (not the old 1GB): offline R3 pitch
# jobs buffer the whole track as float frames plus the stretcher's own
# study buffers (~3-4x a long track). Growth keeps small jobs lean.
FF_O="$SRC/ffmpeg/fftools-objs"; mkdir -p "$FF_O"
FF_CFLAGS=(-I. -I./fftools -I"$PREFIX/include" -Qunused-arguments -O3)
FF_TOOLS_NO_MAIN=(fftools/cmdutils.c fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c fftools/ffmpeg_hw.c fftools/ffmpeg_mux.c fftools/opt_common.c)
(cd "$SRC/ffmpeg" && emcc -c fftools/ffmpeg.c "${FF_CFLAGS[@]}" -Dmain=ffmpeg_tool_main -o "$FF_O/ffmpeg_tool.o")
(cd "$SRC/ffmpeg" && emcc -c fftools/ffprobe.c "${FF_CFLAGS[@]}" -Dmain=ffprobe_tool_main -Dprogram_name=ffprobe_program_name -Dprogram_birth_year=ffprobe_program_birth_year -Dshow_help_default=ffprobe_show_help_default -o "$FF_O/ffprobe_tool.o")
(cd "$SRC/ffmpeg" && for f in "${FF_TOOLS_NO_MAIN[@]}"; do
  emcc -c "$f" "${FF_CFLAGS[@]}" -o "$FF_O/$(basename "$f" .c).o" || exit 1
done)
emcc -c "$ROOT/bridge/bridge.c" $CFLAGS -Qunused-arguments -o "$FF_O/bridge.o"
(cd "$SRC/ffmpeg" && emcc \
  -I. -I./fftools -I"$PREFIX/include" \
  -Llibavcodec -Llibavdevice -Llibavfilter -Llibavformat -Llibavutil -Llibswscale -Llibswresample -Llibpostproc -L"$PREFIX/lib" \
  -Qunused-arguments \
  -lavdevice -lavfilter -lavformat -lavcodec -lswscale -lswresample -lavutil -lpostproc \
  -lmp3lame -lopus -logg -lsoxr -lrubberband ${NONFREE:+-lfdk-aac} -lc++ -lc++abi -lz -lm \
  "$FF_O"/*.o \
  -s INVOKE_RUN=0 -s EXIT_RUNTIME=1 -s MODULARIZE=1 \
  -s EXPORT_NAME=createFFmpegCore \
  -s "EXPORTED_FUNCTIONS=[_ffmpeg,_ffprobe,_malloc]" \
  -s "EXPORTED_RUNTIME_METHODS=[FS, cwrap, ccall, setValue, writeAsciiToMemory, lengthBytesUTF8, stringToUTF8, UTF8ToString]" \
  -s INITIAL_MEMORY=33554432 -s MAXIMUM_MEMORY=2147483648 -s ALLOW_MEMORY_GROWTH=1 \
  --pre-js "$ROOT/bridge/prelude.js" \
  -Wl,--wrap=exit \
  -O3 -o "$OUT/ffmpeg-core.js")

echo "==> verify"
grep -c -i rubberband "$OUT/ffmpeg-core.wasm"
# The @ffmpeg/ffmpeg module worker loads the core via import(), never
# importScripts: it must be a valid ES module (classic <script> users
# don't exist in our flow; Node smoke strips this line).
printf '\nexport default createFFmpegCore;\n' >> "$OUT/ffmpeg-core.js"
grep -c "^export default createFFmpegCore;$" "$OUT/ffmpeg-core.js"
ls -la "$OUT/"
echo OK
