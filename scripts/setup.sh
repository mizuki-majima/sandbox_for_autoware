#!/usr/bin/env bash
# Autoware ＋ scenario_simulator_v2 の実行用 Docker イメージを作る（初回 30〜60 分）。
# Mac / Linux / Windows（WSL2）/ Claude Code のクラウド環境で共通。2 回目以降は差分だけビルドする。
#
# 主な環境変数:
#   BUILD_JOBS / BUILD_WORKERS  ビルドの並列数（既定 2 / 2。メモリ不足で落ちるなら BUILD_JOBS=1）
#   AUTOWARE_IMAGE              ベースにする Autoware イメージ（既定は Dockerfile に記載の動作確認済み版）
#   SIM_VERSION                 scenario_simulator_v2 のバージョン（既定 22.0.0）
#   ROS_APT_MIRROR              ROS の apt ミラー（packages.ros.org に届かない環境向け）
#   PROXY_CA_CERT               プロキシの CA 証明書（TLS を検査するプロキシの内側で使う場合）
set -eo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

detect_platform
ensure_docker
if ! docker buildx version >/dev/null 2>&1; then
  die "BuildKit（docker buildx）が必要です。Docker Desktop か、buildx 入りの Docker Engine を使ってください"
fi
check_resources

build_args=(
  --build-arg "BUILD_JOBS=${BUILD_JOBS:-2}"
  --build-arg "BUILD_WORKERS=${BUILD_WORKERS:-2}"
)
if [ -n "${AUTOWARE_IMAGE:-}" ]; then
  build_args+=(--build-arg "AUTOWARE_IMAGE=${AUTOWARE_IMAGE}")
fi
if [ -n "${SIM_VERSION:-}" ]; then
  build_args+=(--build-arg "SIM_VERSION=${SIM_VERSION}")
fi

# Claude Code のクラウド環境：プロキシの CA を使い、packages.ros.org（HTTP）の代わりに HTTPS のミラーを使う
if [ -f /root/.ccr/ca-bundle.crt ]; then
  PROXY_CA_CERT="${PROXY_CA_CERT:-/root/.ccr/ca-bundle.crt}"
  ROS_APT_MIRROR="${ROS_APT_MIRROR:-https://mirror.umd.edu/packages.ros.org/ros2/ubuntu}"
fi
if [ -n "${ROS_APT_MIRROR:-}" ]; then
  build_args+=(--build-arg "ROS_APT_MIRROR=${ROS_APT_MIRROR}")
fi
if [ -n "${PROXY_CA_CERT:-}" ]; then
  [ -f "${PROXY_CA_CERT}" ] || die "PROXY_CA_CERT のファイルがありません: ${PROXY_CA_CERT}"
  build_args+=(--secret "id=proxy_ca,src=${PROXY_CA_CERT}")
fi

# プロキシ設定をビルドに引き継ぐ。プロキシが localhost 上にある場合はホストのネットワークでビルドする
for name in HTTPS_PROXY https_proxy HTTP_PROXY http_proxy NO_PROXY no_proxy; do
  value="$(printenv "${name}" || true)"
  if [ -n "${value}" ]; then
    build_args+=(--build-arg "${name}=${value}")
  fi
done
case "$(printenv HTTPS_PROXY || printenv https_proxy || true)" in
  *://127.0.0.1:* | *://localhost:* | *://\[::1\]:*) build_args+=(--network host) ;;
esac

log "イメージ ${IMAGE} をビルドします（初回は Autoware イメージの取得とビルドで 30〜60 分ほどかかります）"
DOCKER_BUILDKIT=1 docker build -f "${REPO_DIR}/docker/Dockerfile" -t "${IMAGE}" "${build_args[@]}" "${REPO_DIR}"

log "完了しました。scripts/run.sh でシナリオを実行できます"
