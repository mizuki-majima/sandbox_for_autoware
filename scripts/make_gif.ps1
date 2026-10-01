# 録画（mp4）の一部を GIF にする（Windows 用。中身は make_gif.sh と同じ）。
# ffmpeg はイメージの中のものを使うので、手元に入れなくてよい。
#   使い方: scripts\make_gif.cmd <mp4 ファイル> [開始秒=0] [長さ秒=60] [倍速=3] [幅=720]
#   例)     scripts\make_gif.cmd output\20261001_174441\rviz.mp4 80 115 4
param(
  [string]$Video = '',
  [double]$Start = 0,
  [double]$Duration = 60,
  [double]$Speed = 3,
  [int]$Width = 720
)
$ScriptName = 'make_gif.ps1'
. (Join-Path $PSScriptRoot 'common.ps1')

if (-not $Video -or -not (Test-Path -LiteralPath $Video -PathType Leaf)) {
  Exit-WithError '使い方: scripts\make_gif.cmd <mp4 ファイル> [開始秒=0] [長さ秒=60] [倍速=3] [幅=720]'
}
Assert-Docker
Assert-Image

$videoFull = (Resolve-Path -LiteralPath $Video).Path
$inputDir = Split-Path -Parent $videoFull
$inputFile = Split-Path -Leaf $videoFull
$outputFile = [System.IO.Path]::GetFileNameWithoutExtension($inputFile) + "_${Start}s.gif"
$filter = "setpts=PTS/$Speed,fps=6,scale=${Width}:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer"

$dockerArgs = @('run', '--rm')
if (-not $OnWindows) { $dockerArgs += @('--user', ((& id -u) + ':' + (& id -g))) }
$dockerArgs += @(
  '--mount', "type=bind,source=$inputDir,target=/work", '-w', '/work', $Image,
  'ffmpeg', '-loglevel', 'error', '-y', '-ss', "$Start", '-t', "$Duration", '-i', $inputFile,
  '-vf', $filter, $outputFile
)
& docker @dockerArgs
if ($LASTEXITCODE -ne 0) { Exit-WithError 'GIF を作れませんでした' }
Write-Message ('作成しました: ' + (Join-Path $inputDir $outputFile))
