# イメージの中でシェルを開く（調査・デバッグ用。Windows 用。中身は shell.sh と同じ）。
# ROS / Autoware / シミュレーターの環境は読み込み済み。output\ は /output に見える。
$ScriptName = 'shell.ps1'
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Docker
Assert-Image
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$outputDirFull = (Resolve-Path -LiteralPath $OutputDir).Path

& docker run --rm -it --init --cap-add NET_ADMIN --shm-size 2g `
  --mount "type=bind,source=$outputDirFull,target=/output" $Image bash
exit $LASTEXITCODE
