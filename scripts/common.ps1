# scripts/*.ps1 から読み込む共通処理（Windows 用。中身は common.sh と同じ）。
# Windows 標準の PowerShell 5.1 でも動くよう、PowerShell 7 だけの書き方（??、&& など）は使わない。

$RepoDir = Split-Path -Parent $PSScriptRoot
$OnWindows = ($env:OS -eq 'Windows_NT')

# 環境変数があればその値、なければ既定値を返す
function Get-Setting([string]$Name, [string]$Default) {
  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrEmpty($value)) { return $Default }
  return $value
}

$Image = Get-Setting 'IMAGE' 'sandbox-autoware-sim:latest'
$ContainerName = Get-Setting 'CONTAINER_NAME' 'sandbox-autoware-sim'
$OutputDir = Get-Setting 'OUTPUT_DIR' (Join-Path $RepoDir 'output')

function Write-Message([string]$Message) {
  Write-Host "[$ScriptName] $Message"
}

function Exit-WithError([string]$Message) {
  Write-Host "[$ScriptName] ERROR: $Message" -ForegroundColor Red
  exit 1
}

# 外部コマンドを出力なしで実行し、成功したかどうかを返す
function Test-Native([scriptblock]$Command) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Command *> $null
    return ($LASTEXITCODE -eq 0)
  } catch {
    return $false
  } finally {
    $ErrorActionPreference = $previous
  }
}

# 外部コマンドの標準出力を返す（失敗したら空文字）
function Get-NativeOutput([scriptblock]$Command) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $Command 2> $null
    if ($LASTEXITCODE -ne 0) { return '' }
    return ($output | Out-String).Trim()
  } catch {
    return ''
  } finally {
    $ErrorActionPreference = $previous
  }
}

# Docker に接続でき、Linux コンテナを動かせることを確認する
function Assert-Docker {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    if ($OnWindows) {
      Exit-WithError 'docker コマンドがありません。Docker Desktop をインストールしてください: https://docs.docker.com/desktop/setup/install/windows-install/'
    }
    Exit-WithError 'docker コマンドがありません。Docker をインストールしてください'
  }
  if (-not (Test-Native { docker info })) {
    if ($OnWindows) {
      Exit-WithError 'Docker に接続できません。Docker Desktop を起動し、「Engine running」と表示されてから再実行してください'
    }
    Exit-WithError 'Docker に接続できません。Docker を起動してから再実行してください'
  }
  $osType = Get-NativeOutput { docker info --format '{{.OSType}}' }
  if ($osType -and $osType -ne 'linux') {
    Exit-WithError 'Docker Desktop が Windows コンテナのモードです。タスクトレイの Docker アイコンを右クリックし「Switch to Linux containers」を選んでください'
  }
}

# Docker が使える CPU・メモリを表示し、足りなければ警告する
function Show-DockerResource {
  $ncpu = 0
  [void][int]::TryParse((Get-NativeOutput { docker info --format '{{.NCPU}}' }), [ref]$ncpu)
  $memBytes = 0.0
  [void][double]::TryParse((Get-NativeOutput { docker info --format '{{.MemTotal}}' }), [ref]$memBytes)
  $memGb = [int][math]::Round($memBytes / 1GB)
  Write-Message "Docker が使える CPU: $ncpu コア / メモリ: 約 $memGb GB"
  if ($ncpu -lt 4 -or $memGb -lt 8) {
    Write-Message 'WARN: CPU 4 コア・メモリ 8GB 以上を推奨します'
    if ($OnWindows) {
      Write-Message 'WARN: Docker Desktop（WSL2）の割り当ては %UserProfile%\.wslconfig で増やせます（README の Windows の項を参照）'
    }
  }
}

function Assert-Image {
  if (-not (Test-Native { docker image inspect $Image })) {
    Exit-WithError "イメージ $Image がありません。先に setup を実行してください（Windows は scripts\setup.cmd）"
  }
}
