# 原始碼取得（GPL／LGPL 元件）

依 GPL v3 與 LGPL 的要求，下列是隨 MMV Studio 散布的自由軟體元件的對應原始碼。若下列網址無法取得，請到 https://mmv.tw 聯絡我們索取，我們會提供（至少保留三年）。

## Mac 版（studio-v0.1.3，MMV-Studio-0.1.3-mac-arm64.dmg）

自己編譯，編譯腳本：[build-scripts/build_lgpl_libmpv_macos.sh](build-scripts/build_lgpl_libmpv_macos.sh)（下載、雜湊核對、建置參數都在裡面）。

| 元件 | 版本 | 授權 | 原始碼 |
|---|---|---|---|
| FFmpeg（獨立 ffmpeg／ffprobe，GPL 建置） | 9.0.2 | GPL v3 | https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz |
| FFmpeg 程式庫（libmpv 用，`--disable-gpl`） | 9.0.2 | LGPL v2.1+ | 同上 |
| x264 | commit b35605ace3ddf7c1a5d67a2eb553f034aef41d55 | GPL v2+ | https://code.videolan.org/videolan/x264/-/archive/b35605ace3ddf7c1a5d67a2eb553f034aef41d55/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.bz2 |
| OpenSSL | 3.6.5 | Apache-2.0 | https://github.com/openssl/openssl/releases/download/openssl-3.6.5/openssl-3.6.5.tar.gz |
| mpv（libmpv，`-Dgpl=false`） | 0.41.0 | LGPL v2.1+ | https://github.com/mpv-player/mpv/archive/refs/tags/v0.41.0.tar.gz |
| libplacebo | 7.360.1 | LGPL v2.1+ | https://code.videolan.org/videolan/libplacebo/-/archive/v7.360.1/libplacebo-v7.360.1.tar.bz2 |
| libass | 0.17.5 | ISC | https://github.com/libass/libass/releases/download/0.17.5/libass-0.17.5.tar.xz |
| dav1d | 1.5.4 | BSD-2 | https://code.videolan.org/videolan/dav1d/-/archive/1.5.4/dav1d-1.5.4.tar.bz2 |
| HarfBuzz | 14.6.0 | MIT | https://github.com/harfbuzz/harfbuzz/releases/download/14.6.0/harfbuzz-14.6.0.tar.xz |
| FreeType | 2.14.3 | FreeType License | https://downloads.sourceforge.net/project/freetype/freetype2/2.14.3/freetype-2.14.3.tar.xz |
| FriBidi | 1.0.17 | LGPL v2.1+ | https://github.com/fribidi/fribidi/releases/download/v1.0.17/fribidi-1.0.17.tar.xz |

## Windows 版（studio-v0.1.3，MMV-Studio-Setup-0.1.3.exe）

| 元件 | 版本 | 授權 | 原始碼 |
|---|---|---|---|
| FFmpeg（ffmpeg.exe、ffprobe.exe，GPL 建置） | 9.0.2-full_build（gyan.dev） | GPL v3 | https://www.gyan.dev/ffmpeg/builds/ （該建置頁列出對應原始碼）；FFmpeg：https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz |
| libmpv（libmpv-2.dll，LGPL 建置） | zhongfly/mpv-winbuild 2026-09-25-35af06172b（mpv v0.41.0-1078-g35af06172） | LGPL v2.1+ | https://github.com/zhongfly/mpv-winbuild/releases/tag/2026-09-25-35af06172b ；mpv：https://github.com/mpv-player/mpv |

取得 FFmpeg 的腳本：[build-scripts/get_ffmpeg_windows.ps1](build-scripts/get_ffmpeg_windows.ps1)。建置參數見 `licenses/windows/FFMPEG_BUILD.txt`。

## 兩個平台都有

| 元件 | 授權 | 原始碼 |
|---|---|---|
| Qt 6／PySide6 | LGPL v3 | https://code.qt.io/ 、https://code.qt.io/cgit/pyside/pyside-setup.git/ |
| python-mpv | LGPL v2.1+（擇一授權，採 LGPL） | https://github.com/jaseg/python-mpv |

舊版 0.1.2 與 0.1.3 用的是同一批元件版本，上表同樣適用。
