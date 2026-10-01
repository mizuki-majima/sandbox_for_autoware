# scripts/*.sh から読み込む共通処理。
# macOS 標準の bash 3.2 でも動くよう、新しい bash の機能（連想配列など）や GNU 独自のオプションは使わない。

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-sandbox-autoware-sim:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-sandbox-autoware-sim}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_DIR}/output}"

log() { echo "[$(basename "$0")] $*"; }
die() { echo "[$(basename "$0")] ERROR: $*" >&2; exit 1; }

# PLATFORM に mac / linux / wsl を設定する
detect_platform() {
  case "$(uname -s)" in
    Darwin) PLATFORM=mac ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then PLATFORM=wsl; else PLATFORM=linux; fi
      ;;
    MINGW* | MSYS* | CYGWIN*)
      die "Windows では scripts\\setup.cmd / scripts\\run.cmd を使ってください（Git Bash からは実行できません）"
      ;;
    *) die "未対応の OS です: $(uname -s)" ;;
  esac
}

# Docker に接続できることを確認する（Claude Code のクラウド環境では dockerd を自分で起動する）
ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    case "${PLATFORM}" in
      mac) die "docker コマンドがありません。Docker Desktop をインストールしてください: https://docs.docker.com/desktop/setup/install/mac-install/" ;;
      wsl) die "docker コマンドがありません。Windows 側に Docker Desktop を入れ、Settings → Resources → WSL integration でこの Ubuntu を有効にしてください" ;;
      *) die "docker コマンドがありません。Docker Engine をインストールしてください: https://docs.docker.com/engine/install/" ;;
    esac
  fi
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  # systemd のない root の Linux（Claude Code のクラウド環境など）では dockerd を直接起動する
  if [ "${PLATFORM}" = linux ] && [ "$(id -u)" = 0 ] && command -v dockerd >/dev/null 2>&1 \
    && ! pidof systemd >/dev/null 2>&1; then
    log "Docker デーモンを起動します"
    nohup dockerd >/tmp/dockerd.log 2>&1 &
    for _ in $(seq 1 30); do
      docker info >/dev/null 2>&1 && return 0
      sleep 1
    done
    die "Docker デーモンを起動できませんでした（/tmp/dockerd.log を確認してください）"
  fi
  case "${PLATFORM}" in
    mac) die "Docker に接続できません。Docker Desktop を起動してから再実行してください" ;;
    wsl) die "Docker に接続できません。Docker Desktop を起動し、Settings → Resources → WSL integration でこの Ubuntu を有効にしてください" ;;
    *) die "Docker に接続できません。'sudo systemctl start docker' で起動するか、docker グループに入っているか確認してください" ;;
  esac
}

# Docker が使える CPU・メモリを表示し、足りなければ警告する
check_resources() {
  local ncpu mem_bytes mem_gb
  ncpu="$(docker info --format '{{.NCPU}}' 2>/dev/null || echo 0)"
  mem_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
  mem_gb=$(((mem_bytes + 536870912) / 1073741824))  # GiB に四捨五入
  log "Docker が使える CPU: ${ncpu} コア / メモリ: 約 ${mem_gb} GB"
  if [ "${ncpu}" -lt 4 ] || [ "${mem_gb}" -lt 8 ]; then
    log "WARN: CPU 4 コア・メモリ 8GB 以上を推奨します"
    if [ "${PLATFORM}" = mac ] || [ "${PLATFORM}" = wsl ]; then
      log "WARN: Docker Desktop の Settings → Resources で増やせます"
    fi
  fi
}

ensure_image() {
  docker image inspect "${IMAGE}" >/dev/null 2>&1 \
    || die "イメージ ${IMAGE} がありません。先に scripts/setup.sh を実行してください"
}
