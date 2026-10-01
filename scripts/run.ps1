# シナリオを実行する（Windows 用。中身は run.sh と同じ）。先に scripts\setup.cmd でイメージを作っておく。
# 実行は scripts\run.cmd から。
#   - 実行中は http://localhost:6080 をブラウザで開くと画面（RViz）を見られる
#   - 合否・ログ・録画は output\<日時>\ に保存される
#   - 終了コード: 全シナリオ合格なら 0、それ以外は 0 以外
#
#   例) scripts\run.cmd
#       PowerShell: $env:VIEWER = '0'; scripts\run.cmd
#       コマンドプロンプト: set VIEWER=0 && scripts\run.cmd
#
# 主な環境変数: SCENARIO, REAL_TIME_FACTOR, INITIALIZE_DURATION, GLOBAL_TIMEOUT, VIEWER, RVIZ_VIEW,
#               SIM_NICE, ARCHITECTURE_TYPE, SCREEN_SIZE, RECORD, RECORD_FPS, VIEWER_PORT, OUTPUT_DIR
$ScriptName = 'run.ps1'
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Docker
Assert-Image

$viewerPort = Get-Setting 'VIEWER_PORT' '6080'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$outputDirFull = (Resolve-Path -LiteralPath $OutputDir).Path
$runId = Get-Date -Format 'yyyyMMdd_HHmmss'  # 結果フォルダ名（この PC の時刻）

# 手元のシナリオファイルが指定されたら、そのフォルダをコンテナに読み取り専用で渡す
$scenario = Get-Setting 'SCENARIO' 'sample.yaml'
$scenarioMount = @()
if (Test-Path -LiteralPath $scenario -PathType Leaf) {
  $scenarioFull = (Resolve-Path -LiteralPath $scenario).Path
  $scenarioMount = @('--mount', ('type=bind,source=' + (Split-Path -Parent $scenarioFull) + ',target=/scenarios,readonly'))
  $scenario = '/scenarios/' + (Split-Path -Leaf $scenarioFull)
}

$dockerArgs = @('run', '--rm', '--init')
# 端末から実行したときは Ctrl+C で止められるようにする
if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
  $dockerArgs += '-it'
}
$dockerArgs += @(
  '--name', $ContainerName,
  '--cap-add', 'NET_ADMIN', '--shm-size', '2g',
  '-p', "127.0.0.1:${viewerPort}:6080",
  '--mount', "type=bind,source=$outputDirFull,target=/output"
)
$dockerArgs += $scenarioMount
$dockerArgs += @('-e', "SCENARIO=$scenario", '-e', "RUN_ID=$runId")
if (-not $OnWindows) {
  # Linux / Mac では結果の所有者をこのユーザーに合わせる
  $dockerArgs += @('-e', ('HOST_UID=' + (& id -u)), '-e', ('HOST_GID=' + (& id -g)))
}
foreach ($name in @('ARCHITECTURE_TYPE', 'GLOBAL_TIMEOUT', 'INITIALIZE_DURATION', 'REAL_TIME_FACTOR',
    'VIEWER', 'SCREEN_SIZE', 'RVIZ_VIEW', 'SIM_NICE', 'RECORD', 'RECORD_FPS')) {
  $value = Get-Setting $name ''
  if ($value) { $dockerArgs += @('-e', "$name=$value") }
}
$dockerArgs += @($Image, 'run_scenario')

Test-Native { docker rm -f $ContainerName } | Out-Null

Write-Message 'シナリオを実行します'
if ((Get-Setting 'VIEWER' '1') -ne '0') {
  Write-Message '実行中は次の URL をブラウザで開くと画面（RViz）を見られます'
  Write-Message "  http://localhost:$viewerPort/vnc.html?autoconnect=true&resize=scale"
}

& docker @dockerArgs
$status = $LASTEXITCODE

$resultDir = Join-Path $outputDirFull $runId
if (Test-Path -LiteralPath $resultDir) {
  Write-Message "結果の保存先: $resultDir"
}
exit $status
