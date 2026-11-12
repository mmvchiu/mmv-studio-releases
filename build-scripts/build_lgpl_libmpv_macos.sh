#!/bin/bash
# 在 Mac 上自己編譯 LGPL 的 libmpv（工序 T10）。
#
#   bash packaging/build_lgpl_libmpv_macos.sh            # 編好後印出 libmpv.2.dylib 的位置
#   uv run python packaging/build_macos.py --libmpv ~/mmv-build/prefix/lib/libmpv.2.dylib \
#        --libmpv-license lgpl                            # 用它打包（產物檔名沒有 INTERNAL-GPL）
#
# 為什麼要自己編：Homebrew 的 mpv 是 GPL（-Dgpl=true），載入進 MMV Studio 就讓整個 App 變成 GPL 的
# 組合作品。這裡照 Windows 版的做法（-Dgpl=false）編 LGPL 的 libmpv，而且 libmpv 連到的 FFmpeg
# 程式庫也一起自己編成非 GPL 的（--disable-gpl --disable-nonfree，沒有 x264 之類）。
# 獨立的 ffmpeg／ffprobe 執行檔另外自己編（GPL，含 x264，是另一個程式，沒關係；見最後的第 7 步）。
#
# 為什麼整串依賴都自己編（不用 Homebrew 的 libass、libplacebo、harfbuzz……）：
# Homebrew 的程式庫都是照這台電腦的 macOS（26）編的，一用就把 App 的最低系統版本拉到 26。
# 全部用 MACOSX_DEPLOYMENT_TARGET（預設 13.0）自己編，最低版本才降得下來。
# 編進去的每一個程式庫都是 LGPL 或更寬鬆的授權（見最後印出的清單），**沒有 GPL**。
#
# 原始碼與產物都放 ~/mmv-build/（不進 repo）；每個原始碼壓縮檔都核對 SHA256（同 Homebrew 公式裡的）。
# 已經編好的步驟會跳過（~/mmv-build/stamps/）；要整個重編：刪掉 ~/mmv-build/prefix 與 stamps。
# 需要：Xcode 命令列工具（clang、swift）、pkgconf（brew install pkgconf）、uv；meson 與 ninja
# 裝在 ~/mmv-build/tools 的獨立 Python 環境（不動系統、不碰 Homebrew 的 python）。
set -euo pipefail

BUILD="${MMV_BUILD_DIR:-${HOME}/mmv-build}"
TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
PREFIX="${BUILD}/prefix"            # LGPL 的 libmpv 與它依賴的程式庫
PREFIX_GPL="${BUILD}/prefix-gpl"    # 獨立的 ffmpeg／ffprobe（GPL）；和上面分開，不混在一起
SRC="${BUILD}/src"
STAMPS="${BUILD}/stamps"

# ---- 版本與 SHA256（和 Homebrew 公式裡的一樣，核對過）----
MPV_VERSION=0.41.0
MPV_SHA=ee21092a5ee427353392360929dc64645c54479aefdb5babc5cfbb5fad626209
MPV_URL="https://github.com/mpv-player/mpv/archive/refs/tags/v${MPV_VERSION}.tar.gz"
FFMPEG_VERSION=9.0.2
FFMPEG_SHA=8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
DAV1D_VERSION=1.5.4
DAV1D_SHA=2abfb0c89212e6e4733a54e0ae509ec00a5b845a6360946f918806e14aedb011
DAV1D_URL="https://code.videolan.org/videolan/dav1d/-/archive/${DAV1D_VERSION}/dav1d-${DAV1D_VERSION}.tar.bz2"
FREETYPE_VERSION=2.14.3
FREETYPE_SHA=36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f
FREETYPE_URL="https://downloads.sourceforge.net/project/freetype/freetype2/${FREETYPE_VERSION}/freetype-${FREETYPE_VERSION}.tar.xz"
FRIBIDI_VERSION=1.0.17
FRIBIDI_SHA=6949dcde27d41cebad1fd741fcafc36d55a1020d2d872d4a6eb3914caabbada2
FRIBIDI_URL="https://github.com/fribidi/fribidi/releases/download/v${FRIBIDI_VERSION}/fribidi-${FRIBIDI_VERSION}.tar.xz"
HARFBUZZ_VERSION=14.6.0
HARFBUZZ_SHA=d07a007327277708a2a73ae437887cdbaf282937f6d03ca5467723e9099af586
HARFBUZZ_URL="https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz"
LIBASS_VERSION=0.17.5
LIBASS_SHA=2dca25c0e0c837ddf00b52011b3f82cac1e4ddd3ad018227806b0c2288864acc
LIBASS_URL="https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.xz"
LIBPLACEBO_VERSION=7.360.1
LIBPLACEBO_SHA=937aa5eeea596798b3274d362de2e3bd32bc537a66d149dd85043349c74dffb6
LIBPLACEBO_URL="https://code.videolan.org/videolan/libplacebo/-/archive/v${LIBPLACEBO_VERSION}/libplacebo-v${LIBPLACEBO_VERSION}.tar.bz2"
FAST_FLOAT_VERSION=8.3.1
FAST_FLOAT_SHA=7ff47ad261068517561beb0a7c1d57131f71b8be19bdbac2857c6a517a2eb53c
FAST_FLOAT_URL="https://github.com/fastfloat/fast_float/archive/refs/tags/v${FAST_FLOAT_VERSION}.tar.gz"
# libplacebo 就算不開 Vulkan，原始碼還是要 Vulkan 的標頭檔（只要標頭檔，Apache-2.0，不連結任何東西）
VULKAN_HEADERS_VERSION=1.4.363.0
VULKAN_HEADERS_SHA=4a078be12bef21cfebc09d878b77a63cff9d68f899254a0b00d0e37ef73e7f7e
VULKAN_HEADERS_URL="https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/vulkan-sdk-${VULKAN_HEADERS_VERSION}.tar.gz"
# libplacebo 的建置要用的三個 Python 套件（只在建置時用，不進 App）
GLAD2_URL="https://files.pythonhosted.org/packages/6e/5a/d62b24fe1c7c2f34e15c2aa4418a5327a8550fdc272999a59e0dddebc3ee/glad2-2.0.8.tar.gz"
GLAD2_SHA=b84079b9fa404f37171b961bdd1d8da21370e6c818defb8481c5b3fe3d6436da
JINJA2_URL="https://files.pythonhosted.org/packages/df/bf/f7da0350254c0ed7c72f3e33cef02e048281fec7ecec5f032d4aac52226b/jinja2-3.1.6.tar.gz"
JINJA2_SHA=0137fb05990d35f1275a587e9aee6d56da821fc83491a0fb838183be43f66d6d
MARKUPSAFE_URL="https://files.pythonhosted.org/packages/7e/99/7690b6d4034fffd95959cbe0c02de8deb3098cc577c67bb6a24fe5d7caa7/markupsafe-3.0.3.tar.gz"
MARKUPSAFE_SHA=722695808f4b6457b320fdc131280796bdceb04ab50fe1795cd540799ebe1698
# 獨立的 ffmpeg／ffprobe（GPL）要用的：x264（GPL-2.0-or-later）、OpenSSL（Apache-2.0，RTMPS 的 TLS 用）
X264_COMMIT=b35605ace3ddf7c1a5d67a2eb553f034aef41d55
X264_SHA=6eeb82934e69fd51e043bd8c5b0d152839638d1ce7aa4eea65a3fedcf83ff224
X264_URL="https://code.videolan.org/videolan/x264/-/archive/${X264_COMMIT}/x264-${X264_COMMIT}.tar.bz2"
OPENSSL_VERSION=3.6.5
OPENSSL_SHA=a2157c2830efdec3788939b00c9b0638306d3f0bbb76dc4832ee503bb397df98
OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
MESON_VERSION=1.12.1
NINJA_VERSION=1.13.2

say() { printf '\n== %s\n' "$*"; }
die() { printf '停下來：%s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || die "這支腳本只能在 Mac 上跑。"
command -v pkgconf >/dev/null || command -v pkg-config >/dev/null || die "找不到 pkgconf。請先 brew install pkgconf。"
command -v clang >/dev/null || die "找不到 clang。請先安裝 Xcode 命令列工具（xcode-select --install）。"
command -v uv >/dev/null || die "找不到 uv。"
[ -n "${BUILD}" ] && [ "${BUILD}" != "/" ] || die "MMV_BUILD_DIR 不能是空的或根目錄。"
mkdir -p "${SRC}" "${STAMPS}" "${PREFIX}" "${PREFIX_GPL}"

# ---- 環境：全部用同一個最低系統版本，而且只看自己的 prefix（不看 Homebrew 的 .pc）----
export MACOSX_DEPLOYMENT_TARGET="${TARGET}"
export CFLAGS="-mmacosx-version-min=${TARGET} -O2"
export CXXFLAGS="-mmacosx-version-min=${TARGET} -O2"
export LDFLAGS="-mmacosx-version-min=${TARGET} -L${PREFIX}/lib"
export CPPFLAGS="-I${PREFIX}/include"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"
unset PKG_CONFIG_PATH
export PATH="${BUILD}/tools/bin:${PATH}"

# ---- 建置工具（獨立的 Python 環境，不動系統）----
if [ ! -x "${BUILD}/tools/bin/meson" ]; then
  say "建置工具 meson ${MESON_VERSION}、ninja ${NINJA_VERSION}（裝在 ${BUILD}/tools）"
  uv venv -q "${BUILD}/tools" --python 3.12
  uv pip install -q --python "${BUILD}/tools/bin/python" "meson==${MESON_VERSION}" "ninja==${NINJA_VERSION}"
fi

fetch() { # 名稱 網址 sha256 檔名
  local file="${SRC}/$4"
  if [ ! -f "${file}" ]; then
    say "下載 $1"
    curl -fL --retry 3 -o "${file}.part" "$2"
    mv "${file}.part" "${file}"
  fi
  echo "$3  ${file}" | shasum -a 256 -c - >/dev/null || die "$4 的 SHA256 不對（預期 $3）。檔案可能被換過，不要用。"
}

unpack() { # 壓縮檔名 解開後的資料夾名（先清掉舊的）
  local archive="${1:?}" dir="${2:?}"
  rm -rf "${SRC:?}/${dir:?}"
  tar -xf "${SRC}/${archive}" -C "${SRC}"
}

stamped() { [ -f "${STAMPS}/$1" ]; }
mark() { touch "${STAMPS}/$1"; }

fetch dav1d "${DAV1D_URL}" "${DAV1D_SHA}" "dav1d-${DAV1D_VERSION}.tar.bz2"
fetch freetype "${FREETYPE_URL}" "${FREETYPE_SHA}" "freetype-${FREETYPE_VERSION}.tar.xz"
fetch fribidi "${FRIBIDI_URL}" "${FRIBIDI_SHA}" "fribidi-${FRIBIDI_VERSION}.tar.xz"
fetch harfbuzz "${HARFBUZZ_URL}" "${HARFBUZZ_SHA}" "harfbuzz-${HARFBUZZ_VERSION}.tar.xz"
fetch libass "${LIBASS_URL}" "${LIBASS_SHA}" "libass-${LIBASS_VERSION}.tar.xz"
fetch ffmpeg "${FFMPEG_URL}" "${FFMPEG_SHA}" "ffmpeg-${FFMPEG_VERSION}.tar.xz"
fetch libplacebo "${LIBPLACEBO_URL}" "${LIBPLACEBO_SHA}" "libplacebo-v${LIBPLACEBO_VERSION}.tar.bz2"
fetch vulkan-headers "${VULKAN_HEADERS_URL}" "${VULKAN_HEADERS_SHA}" "vulkan-headers-${VULKAN_HEADERS_VERSION}.tar.gz"
fetch fast_float "${FAST_FLOAT_URL}" "${FAST_FLOAT_SHA}" "fast_float-${FAST_FLOAT_VERSION}.tar.gz"
fetch glad2 "${GLAD2_URL}" "${GLAD2_SHA}" "glad2-2.0.8.tar.gz"
fetch jinja2 "${JINJA2_URL}" "${JINJA2_SHA}" "jinja2-3.1.6.tar.gz"
fetch markupsafe "${MARKUPSAFE_URL}" "${MARKUPSAFE_SHA}" "markupsafe-3.0.3.tar.gz"
fetch x264 "${X264_URL}" "${X264_SHA}" "x264-${X264_COMMIT}.tar.bz2"
fetch openssl "${OPENSSL_URL}" "${OPENSSL_SHA}" "openssl-${OPENSSL_VERSION}.tar.gz"
fetch mpv "${MPV_URL}" "${MPV_SHA}" "mpv-${MPV_VERSION}.tar.gz"

meson_build() { # 名稱 資料夾 [meson 選項...]
  local name="$1" dir="$2"
  shift 2
  ( cd "${SRC}/${dir}" &&
    rm -rf ./build &&
    meson setup build --prefix="${PREFIX}" --buildtype=release --default-library=shared "$@" &&
    meson compile -C build -j "${JOBS}" && meson install -C build ) || die "${name} 編不起來（看上面的訊息）。"
}

# ---- 1. dav1d（AV1 解碼，BSD）----
if ! stamped dav1d; then
  say "編 dav1d ${DAV1D_VERSION}"
  unpack "dav1d-${DAV1D_VERSION}.tar.bz2" "dav1d-${DAV1D_VERSION}"
  meson_build dav1d "dav1d-${DAV1D_VERSION}" -Denable_tools=false -Denable_tests=false -Denable_examples=false
  mark dav1d
fi

# ---- 2. freetype（FreeType License／GPLv2 二選一，採 FTL）、fribidi（LGPL）、harfbuzz（MIT）、libass（ISC）----
if ! stamped freetype; then
  say "編 freetype ${FREETYPE_VERSION}"
  unpack "freetype-${FREETYPE_VERSION}.tar.xz" "freetype-${FREETYPE_VERSION}"
  meson_build freetype "freetype-${FREETYPE_VERSION}" -Dharfbuzz=disabled -Dpng=disabled -Dbzip2=disabled \
    -Dbrotli=disabled -Dzlib=system
  mark freetype
fi
if ! stamped fribidi; then
  say "編 fribidi ${FRIBIDI_VERSION}"
  unpack "fribidi-${FRIBIDI_VERSION}.tar.xz" "fribidi-${FRIBIDI_VERSION}"
  meson_build fribidi "fribidi-${FRIBIDI_VERSION}" -Ddocs=false -Dbin=false -Dtests=false
  mark fribidi
fi
if ! stamped harfbuzz; then
  say "編 harfbuzz ${HARFBUZZ_VERSION}"
  unpack "harfbuzz-${HARFBUZZ_VERSION}.tar.xz" "harfbuzz-${HARFBUZZ_VERSION}"
  meson_build harfbuzz "harfbuzz-${HARFBUZZ_VERSION}" -Dfreetype=enabled -Dcoretext=enabled -Dglib=disabled \
    -Dgobject=disabled -Dicu=disabled -Dcairo=disabled -Dtests=disabled -Ddocs=disabled -Dbenchmark=disabled \
    -Dutilities=disabled
  mark harfbuzz
fi
if ! stamped libass; then
  say "編 libass ${LIBASS_VERSION}"
  unpack "libass-${LIBASS_VERSION}.tar.xz" "libass-${LIBASS_VERSION}"
  ( cd "${SRC}/libass-${LIBASS_VERSION}" &&
    ./configure --prefix="${PREFIX}" --disable-static --enable-shared --disable-fontconfig \
      --disable-libunibreak --disable-asm &&
    make -j "${JOBS}" && make install ) || die "libass 編不起來。"
  mark libass
fi

# ---- 3. FFmpeg 程式庫（LGPL；只給 libmpv 用，沒有執行檔）----
if ! stamped ffmpeg; then
  say "編 FFmpeg ${FFMPEG_VERSION}（--disable-gpl --disable-nonfree，LGPL）"
  unpack "ffmpeg-${FFMPEG_VERSION}.tar.xz" "ffmpeg-${FFMPEG_VERSION}"
  ( cd "${SRC}/ffmpeg-${FFMPEG_VERSION}" &&
    ./configure --prefix="${PREFIX}" --enable-shared --disable-static --disable-gpl --disable-nonfree \
      --disable-programs --disable-doc --disable-debug --disable-autodetect \
      --enable-videotoolbox --enable-audiotoolbox --enable-zlib --enable-iconv --enable-libdav1d \
      --extra-cflags="-mmacosx-version-min=${TARGET} -I${PREFIX}/include" \
      --extra-ldflags="-mmacosx-version-min=${TARGET} -L${PREFIX}/lib" --extra-libs=-liconv &&
    make -j "${JOBS}" && make install ) || die "FFmpeg 編不起來。"
  mark ffmpeg
fi

# ---- 4. libplacebo（LGPL；mpv 一定要它。只開 OpenGL，不要 Vulkan、shaderc、lcms）----
if ! stamped libplacebo; then
  say "編 libplacebo ${LIBPLACEBO_VERSION}"
  unpack "libplacebo-v${LIBPLACEBO_VERSION}.tar.bz2" "libplacebo-v${LIBPLACEBO_VERSION}"
  third="${SRC}/libplacebo-v${LIBPLACEBO_VERSION}/3rdparty"
  mkdir -p "${third}"
  for pair in "glad:glad2-2.0.8" "jinja:jinja2-3.1.6" "markupsafe:markupsafe-3.0.3"; do
    dest="${pair%%:*}"
    folder="${pair##*:}"
    unpack "${folder}.tar.gz" "${folder}"
    rm -rf "${third:?}/${dest:?}"
    mv "${SRC}/${folder}" "${third}/${dest}"
  done
  unpack "fast_float-${FAST_FLOAT_VERSION}.tar.gz" "fast_float-${FAST_FLOAT_VERSION}"
  mkdir -p "${third}/fast_float"
  unpack "vulkan-headers-${VULKAN_HEADERS_VERSION}.tar.gz" "Vulkan-Headers-vulkan-sdk-${VULKAN_HEADERS_VERSION}"
  mkdir -p "${PREFIX}/include"
  cp -R "${SRC}/Vulkan-Headers-vulkan-sdk-${VULKAN_HEADERS_VERSION}/include/vulkan" "${PREFIX}/include/"
  cp -R "${SRC}/Vulkan-Headers-vulkan-sdk-${VULKAN_HEADERS_VERSION}/include/vk_video" "${PREFIX}/include/"
  rm -rf "${third:?}/fast_float/include"
  mv "${SRC}/fast_float-${FAST_FLOAT_VERSION}/include" "${third}/fast_float/include"
  meson_build libplacebo "libplacebo-v${LIBPLACEBO_VERSION}" -Dvulkan=disabled -Dopengl=enabled \
    -Dgl-proc-addr=enabled -Dd3d11=disabled -Dglslang=disabled -Dshaderc=disabled -Dlcms=disabled \
    -Ddovi=disabled -Dlibdovi=disabled -Dunwind=disabled -Dxxhash=disabled -Ddemos=false -Dtests=false \
    -Dbench=false -Dfuzz=false
  mark libplacebo
fi

# ---- 5. libmpv（-Dgpl=false，只要 libmpv，不要命令列的 mpv）----
if ! stamped mpv; then
  say "編 mpv ${MPV_VERSION} 的 libmpv（-Dgpl=false，LGPL）"
  unpack "mpv-${MPV_VERSION}.tar.gz" "mpv-${MPV_VERSION}"
  meson_build mpv "mpv-${MPV_VERSION}" -Dgpl=false -Dlibmpv=true -Dcplayer=false -Dbuild-date=false \
    -Dauto_features=disabled -Dgl=enabled -Dplain-gl=enabled -Dcocoa=enabled -Dgl-cocoa=enabled \
    -Dmacos-cocoa-cb=enabled -Dswift-build=enabled -Dvideotoolbox-gl=enabled -Dcoreaudio=enabled \
    -Davfoundation=enabled -Diconv=enabled -Dzlib=enabled -Dlua=disabled -Djavascript=disabled
  mark mpv
fi

# ---- 7. 獨立的 ffmpeg／ffprobe（GPL，另一個程式）：靜態連 x264 與 OpenSSL，只依賴系統程式庫 ----
# Homebrew 的 ffmpeg 是照 macOS 26 編的，用它會把整個 App 的最低系統版本又拉回 26，所以也自己編。
if ! stamped ffmpeg-gpl; then
  say "編獨立的 ffmpeg／ffprobe（GPL）：OpenSSL ${OPENSSL_VERSION}、x264、FFmpeg ${FFMPEG_VERSION}"
  case "$(uname -m)" in
    arm64) ssl_target=darwin64-arm64-cc ;;
    *) ssl_target=darwin64-x86_64-cc ;;
  esac
  unpack "openssl-${OPENSSL_VERSION}.tar.gz" "openssl-${OPENSSL_VERSION}"
  ( cd "${SRC}/openssl-${OPENSSL_VERSION}" &&
    ./Configure "${ssl_target}" no-shared no-tests no-docs no-apps "-mmacosx-version-min=${TARGET}" \
      --prefix="${PREFIX_GPL}" --openssldir="${PREFIX_GPL}/ssl" &&
    make -j "${JOBS}" && make install_sw ) || die "OpenSSL 編不起來。"
  unpack "x264-${X264_COMMIT}.tar.bz2" "x264-${X264_COMMIT}"
  ( cd "${SRC}/x264-${X264_COMMIT}" &&
    ./configure --prefix="${PREFIX_GPL}" --enable-static --disable-cli --disable-opencl \
      --extra-cflags="-mmacosx-version-min=${TARGET}" --extra-ldflags="-mmacosx-version-min=${TARGET}" &&
    make -j "${JOBS}" && make install ) || die "x264 編不起來。"
  unpack "ffmpeg-${FFMPEG_VERSION}.tar.xz" "ffmpeg-${FFMPEG_VERSION}"
  ( cd "${SRC}/ffmpeg-${FFMPEG_VERSION}" &&
    PKG_CONFIG_LIBDIR="${PREFIX_GPL}/lib/pkgconfig" ./configure --prefix="${PREFIX_GPL}" \
      --disable-shared --enable-static --enable-gpl --enable-version3 --disable-nonfree \
      --disable-doc --disable-debug --disable-ffplay --disable-autodetect \
      --enable-libx264 --enable-openssl --enable-avfoundation --enable-audiotoolbox \
      --enable-videotoolbox --enable-zlib --enable-iconv --pkg-config-flags=--static \
      --extra-cflags="-mmacosx-version-min=${TARGET} -I${PREFIX_GPL}/include" \
      --extra-ldflags="-mmacosx-version-min=${TARGET} -L${PREFIX_GPL}/lib" --extra-libs=-liconv &&
    make -j "${JOBS}" && make install ) || die "獨立的 ffmpeg 編不起來。"
  mark ffmpeg-gpl
fi

# ---- 6. 檢查：只依賴自己的 prefix 與系統、最低 macOS、授權 ----
say "檢查"
LIB="${PREFIX}/lib/libmpv.2.dylib"
[ -f "${LIB}" ] || die "沒有產生 ${LIB}"
bad=0
max_minos=0
closure=()
queue=("${LIB}")
while [ ${#queue[@]} -gt 0 ]; do
  f="${queue[0]}"
  queue=("${queue[@]:1}")
  case " ${closure[*]:-} " in *" ${f} "*) continue ;; esac
  closure+=("${f}")
  minos=$(vtool -show-build "${f}" 2>/dev/null | awk '/minos/ {print $2; exit}')
  if [ -n "${minos}" ] && [ "$(printf '%s\n%s\n' "${max_minos}" "${minos}" | sort -V | tail -1)" = "${minos}" ]; then
    max_minos="${minos}"
  fi
  while read -r dep; do
    case "${dep}" in
      "${PREFIX}"/*) queue+=("${dep}") ;;
      /usr/lib/* | /System/Library/*) ;;
      *)
        echo "不該有的依賴：${f} → ${dep}"
        bad=1
        ;;
    esac
  done < <(otool -L "${f}" | tail -n +2 | awk '{print $1}')
done
[ "${bad}" = 0 ] || die "libmpv 依賴了 prefix 與系統以外的東西（可能連到 Homebrew 的）。"
echo "libmpv 與它依賴的程式庫共 ${#closure[@]} 個，最低 macOS 要求：${max_minos}（目標 ${TARGET}）"
printf '  %s\n' "${closure[@]##*/}" | sort

say "檢查獨立的 ffmpeg／ffprobe（只能依賴系統、最低 macOS）"
for tool in ffmpeg ffprobe; do
  f="${PREFIX_GPL}/bin/${tool}"
  [ -x "${f}" ] || die "沒有產生 ${f}"
  while read -r dep; do
    case "${dep}" in
      /usr/lib/* | /System/Library/*) ;;
      *) die "${tool} 依賴了系統以外的東西：${dep}" ;;
    esac
  done < <(otool -L "${f}" | tail -n +2 | awk '{print $1}')
  echo "${tool}：最低 macOS $(vtool -show-build "${f}" | awk '/minos/ {print $2; exit}')，$("${f}" -version | head -1 | cut -c1-60)"
done

say "收集各程式庫的授權文字（build_macos.py 會放進 App 的 licenses 資料夾）"
mkdir -p "${BUILD}/licenses"
collect_license() { # 名稱 原始碼資料夾裡的檔案
  local from="${SRC}/$2"
  [ -f "${from}" ] || die "找不到 ${from}（授權文字，一定要附）。"
  cp "${from}" "${BUILD}/licenses/LICENSE-$1.txt"
}
collect_license libmpv "mpv-${MPV_VERSION}/LICENSE.LGPL"
collect_license ffmpeg-lgpl "ffmpeg-${FFMPEG_VERSION}/COPYING.LGPLv2.1"
collect_license ffmpeg-gpl "ffmpeg-${FFMPEG_VERSION}/COPYING.GPLv3"
collect_license libplacebo "libplacebo-v${LIBPLACEBO_VERSION}/LICENSE"
collect_license libass "libass-${LIBASS_VERSION}/COPYING"
collect_license harfbuzz "harfbuzz-${HARFBUZZ_VERSION}/COPYING"
collect_license freetype "freetype-${FREETYPE_VERSION}/docs/FTL.TXT"
collect_license fribidi "fribidi-${FRIBIDI_VERSION}/COPYING"
collect_license dav1d "dav1d-${DAV1D_VERSION}/COPYING"
collect_license x264 "x264-${X264_COMMIT}/COPYING"
collect_license openssl "openssl-${OPENSSL_VERSION}/LICENSE.txt"
collect_license fast_float "fast_float-${FAST_FLOAT_VERSION}/LICENSE-APACHE"
echo "授權文字 $(ls "${BUILD}/licenses" | wc -l | tr -d ' ') 份在 ${BUILD}/licenses"

say "授權（每個編進去的程式庫）"
cat <<LIC
  libmpv     ${MPV_VERSION}   LGPL-2.1-or-later（-Dgpl=false）
  FFmpeg     ${FFMPEG_VERSION}   LGPL-2.1-or-later（--disable-gpl --disable-nonfree）
  libplacebo ${LIBPLACEBO_VERSION} LGPL-2.1-or-later
  libass     ${LIBASS_VERSION}   ISC
  harfbuzz   ${HARFBUZZ_VERSION}  MIT
  freetype   ${FREETYPE_VERSION}  FreeType License（BSD 類，也可選 GPLv2；我們採 FTL）
  fribidi    ${FRIBIDI_VERSION}   LGPL-2.1-or-later（程式庫本身；Homebrew 標的 GPL 是它的工具與測試，沒有編進去）
  dav1d      ${DAV1D_VERSION}   BSD-2-Clause
  （獨立的 ffmpeg／ffprobe，另一個程式，GPL-3.0-or-later：FFmpeg ${FFMPEG_VERSION}、x264 r3222（GPL-2.0-or-later）、OpenSSL ${OPENSSL_VERSION}（Apache-2.0））
LIC
say "完成"
echo "libmpv：${LIB}"
echo "ffmpeg／ffprobe：${PREFIX_GPL}/bin"
echo "接著：uv run python packaging/build_macos.py --libmpv ${LIB} --libmpv-license lgpl --ffmpeg-dir ${PREFIX_GPL}/bin"
