# Autoware ＋ scenario_simulator_v2 の実行用 Docker イメージを作る（Windows 用。中身は setup.sh と同じ）。
# 実行は scripts\setup.cmd から（PowerShell の実行ポリシーを変えなくても動く）。初回 30〜60 分。
#
# 主な環境変数（PowerShell なら $env:BUILD_JOBS = '1' のように指定）:
#   BUILD_JOBS / BUILD_WORKERS  ビルドの並列数（既定 2 / 2。メモリ不足で落ちるなら BUILD_JOBS=1）
#   AUTOWARE_IMAGE / SIM_VERSION  ベースの Autoware イメージ / scenario_simulator_v2 のバージョン
#   HTTPS_PROXY / HTTP_PROXY / NO_PROXY  社内プロキシ
#   PROXY_CA_CERT               プロキシの CA 証明書（TLS を検査するプロキシの内側で使う場合）
#   ROS_APT_MIRROR              ROS の apt ミラー（packages.ros.org に届かない環境向け）
$ScriptName = 'setup.ps1'
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Docker
if (-not (Test-Native { docker buildx version })) {
  Exit-WithError 'BuildKit（docker buildx）が必要です。Docker Desktop を最新版にしてください'
}
Show-DockerResource

$buildArgs = @(
  'build',
  '-f', (Join-Path (Join-Path $RepoDir 'docker') 'Dockerfile'),
  '-t', $Image,
  '--build-arg', ('BUILD_JOBS=' + (Get-Setting 'BUILD_JOBS' '2')),
  '--build-arg', ('BUILD_WORKERS=' + (Get-Setting 'BUILD_WORKERS' '2'))
)
foreach ($name in @('AUTOWARE_IMAGE', 'SIM_VERSION')) {
  $value = Get-Setting $name ''
  if ($value) { $buildArgs += @('--build-arg', "$name=$value") }
}

# Claude Code のクラウド環境（Linux）向けの設定。setup.sh と同じ
$proxyCa = Get-Setting 'PROXY_CA_CERT' ''
$rosMirror = Get-Setting 'ROS_APT_MIRROR' ''
if ((-not $OnWindows) -and (Test-Path -LiteralPath '/root/.ccr/ca-bundle.crt')) {
  if (-not $proxyCa) { $proxyCa = '/root/.ccr/ca-bundle.crt' }
  if (-not $rosMirror) { $rosMirror = 'https://mirror.umd.edu/packages.ros.org/ros2/ubuntu' }
}
if ($rosMirror) { $buildArgs += @('--build-arg', "ROS_APT_MIRROR=$rosMirror") }
if ($proxyCa) {
  if (-not (Test-Path -LiteralPath $proxyCa -PathType Leaf)) {
    Exit-WithError "PROXY_CA_CERT のファイルがありません: $proxyCa"
  }
  $buildArgs += @('--secret', ('id=proxy_ca,src=' + (Resolve-Path -LiteralPath $proxyCa).Path))
}

# プロキシ設定をビルドに引き継ぐ。
# プロキシが localhost 上にある場合、Docker Desktop（Windows / Mac）では host.docker.internal に読み替え、
# Linux ではホストのネットワークでビルドする
$useHostNetwork = $false
foreach ($name in @('HTTPS_PROXY', 'HTTP_PROXY', 'NO_PROXY')) {
  $value = Get-Setting $name ''
  if (-not $value) { $value = Get-Setting $name.ToLower() '' }
  if (-not $value) { continue }
  if ($name -ne 'NO_PROXY' -and $value -match '://(127\.0\.0\.1|localhost|\[::1\])(:|/|$)') {
    if ($OnWindows -or $IsMacOS) {
      $value = $value -replace '://(127\.0\.0\.1|localhost|\[::1\])', '://host.docker.internal'
    } else {
      $useHostNetwork = $true
    }
  }
  $buildArgs += @('--build-arg', "$name=$value", '--build-arg', ($name.ToLower() + "=$value"))
}
if ($useHostNetwork) { $buildArgs += @('--network', 'host') }
$buildArgs += $RepoDir

$env:DOCKER_BUILDKIT = '1'
Write-Message "イメージ $Image をビルドします（初回は Autoware イメージの取得とビルドで 30〜60 分ほどかかります）"
& docker @buildArgs
if ($LASTEXITCODE -ne 0) {
  Exit-WithError 'イメージを作れませんでした。上のログを確認してください（README のトラブルシューティングも参照）'
}

if ($OnWindows) {
  Write-Message '完了しました。scripts\run.cmd でシナリオを実行できます'
} else {
  Write-Message '完了しました。scripts/run.ps1（または scripts/run.sh）でシナリオを実行できます'
}
