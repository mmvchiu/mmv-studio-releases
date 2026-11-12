# 取得安裝包要附的 FFmpeg（Gyan「essentials」建置，工序 5.6 安裝檔瘦身），放進 vendor\ffmpeg\。
#   cd code\studio
#   .\packaging\get_ffmpeg_windows.ps1                 # 下載、核對雜湊、核對功能、放進 vendor\ffmpeg
#   .\packaging\get_ffmpeg_windows.ps1 -ZipPath C:\x\ffmpeg-release-essentials.zip   # 已經下載好了就指定檔案
#
# 為什麼是 essentials：完整建置（Gyan full）每個執行檔約 217 MB，帶了 Studio 用不到的一大堆函式庫
# （藍光、紅外線遙控、各種濾鏡函式庫……）；essentials 小很多，仍含 libx264、libsrt、dshow、gdigrab，
# Studio 用到的濾鏡（xfade、overlay、ebur128、alimiter……）都是 FFmpeg 內建的。
# 但「小很多」不等於「夠用」：下載後會逐項核對 Studio 用到的功能（studio\core\ffmpeg_needs.py）並真的編碼 1 秒，
# 缺任何一項就拒絕放進 vendor\。build_windows.ps1 打包前還會再核對一次。
#
# 下載的檔案一律當不可信的資料：放在全新的空資料夾（build\ffmpeg-download-<隨機>），核對 SHA256 後才解開，
# 腳本本身放在別處，不在下載資料夾裡執行任何東西（只執行解開後的 ffmpeg.exe 做功能核對）。
# SHA256 取自 Gyan 網站同一頁的 .sha256 檔：能擋下載到一半壞掉、被換成別的檔，擋不了網站本身被入侵；
# 要更嚴可以再和 winget 套件清單（Gyan.FFmpeg.Essentials）裡的雜湊比對。
param(
    [string]$Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
    [string]$ZipPath = "",
    [string]$OutDir = "vendor\ffmpeg"
)
$ErrorActionPreference = "Stop"
$Studio = Split-Path -Parent $PSScriptRoot
Set-Location $Studio
function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }

# ---- 新的空資料夾 ----
$work = Join-Path $Studio ("build\ffmpeg-download-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force $work | Out-Null

# ---- 下載與核對雜湊 ----
if ($ZipPath) {
    $zip = (Resolve-Path $ZipPath).Path
    $expected = $null
    Write-Warning "用指定的檔案 $zip ：沒有可比對的 .sha256，只會做功能核對。"
} else {
    Step "下載 $Url"
    $zip = Join-Path $work "ffmpeg.zip"
    $ProgressPreference = "SilentlyContinue"   # PowerShell 5.1 的進度條會讓下載慢 10 倍以上
    Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing
    $expected = ((Invoke-WebRequest -Uri "$Url.sha256" -UseBasicParsing).Content.ToString().Trim() -split "\s+")[0].ToLower()
}
$actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($expected -and $actual -ne $expected) { throw "SHA256 不符（下載到 $actual，網站公布 $expected）。不要用這個檔案。" }
"SHA256：$actual"

# ---- 解開（只取要用的三個檔案）----
Step "解開"
$extract = Join-Path $work "extracted"
Expand-Archive -Path $zip -DestinationPath $extract -Force
$exe = Get-ChildItem $extract -Recurse -Filter ffmpeg.exe | Select-Object -First 1
if (-not $exe) { throw "壓縮檔裡找不到 ffmpeg.exe" }
$bin = $exe.DirectoryName
$ffmpeg = Join-Path $bin "ffmpeg.exe"
$ffprobe = Join-Path $bin "ffprobe.exe"
if (-not (Test-Path $ffprobe)) { throw "壓縮檔裡找不到 ffprobe.exe" }
$version = ((& $ffmpeg -version 2>&1) | Select-Object -First 1)
"解開的是：$version"

# ---- 核對 Studio 要的功能（缺任何一項就停）----
Step "核對 Studio 用到的 FFmpeg 功能，並試編碼 1 秒"
uv run python -m studio.core.ffmpeg_needs $ffmpeg --platform windows --smoke
if ($LASTEXITCODE -ne 0) { throw "這份 FFmpeg 少了 Studio 要用的功能（上面 [X] 的項目）。沒有放進 $OutDir 。" }

# ---- 放進 vendor ----
Step "放進 $OutDir"
New-Item -ItemType Directory -Force $OutDir | Out-Null
Copy-Item $ffmpeg, $ffprobe $OutDir -Force
$source = @(
    "下載網址：$(if ($ZipPath) { '（使用者指定的檔案）' } else { $Url })",
    "壓縮檔 SHA256：$actual",
    "取得日期：$(Get-Date -Format 'yyyy-MM-dd')"
)
$source | Out-File (Join-Path $OutDir "SOURCE.txt") -Encoding utf8
$mb = ((Get-Item (Join-Path $OutDir "ffmpeg.exe")).Length + (Get-Item (Join-Path $OutDir "ffprobe.exe")).Length) / 1MB
"完成：ffmpeg.exe 與 ffprobe.exe 共 {0:N0} MB（完整建置約 434 MB）" -f $mb
Write-Host "下一步：.\packaging\build_windows.ps1"
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
