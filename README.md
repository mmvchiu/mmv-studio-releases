# MMV Studio 下載

MMV Studio 是 MMV（mmv.tw）的桌機導播軟體。這個資料庫只放安裝檔、授權文字與原始碼取得說明。
下載請到 **https://mmv.tw/studio**，或本頁右側的 Releases。

## 安裝（未簽章版）

- **Mac（Apple Silicon，macOS 15 以上）**：打開 .dmg，把 MMV Studio 拖進「應用程式」。第一次開啟要在 App 上**按右鍵 →「打開」**，再按一次「打開」。之後直接點兩下就好。
- **Windows 10／11（64 位元）**：執行安裝檔時若出現 SmartScreen「Windows 已保護您的電腦」，按 **「其他資訊」→「仍要執行」**。

下載後可以比對 SHA256（Release 頁與 mmv.tw/studio 都有寫）：
- Mac：`shasum -a 256 MMV-Studio-0.1.2-mac-arm64.dmg`
- Windows：`certutil -hashfile MMV-Studio-Setup-0.1.2.exe SHA256`

## 授權與第三方軟體

完整清單在 `licenses/`（也隨安裝檔附上）。重點：
- **libmpv**（播放引擎）：LGPL-2.1-or-later（`-Dgpl=false` 建置），MMV Studio 以動態連結使用，你可以換成自己編譯的相容版本。
- **FFmpeg（ffmpeg、ffprobe）**：GPL v3，含 x264；是獨立的執行檔，MMV Studio 把它當成另一個程式呼叫。
- **Qt／PySide6**：LGPL v3。

原始碼取得方式見 [SOURCE.md](SOURCE.md)。
