#!/usr/bin/env bash
# イメージの中でシェルを開く（調査・デバッグ用）。ROS / Autoware / シミュレーターの環境は読み込み済み。
#   output/ は /output に見える
set -eo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

detect_platform
ensure_docker
ensure_image
mkdir -p "${OUTPUT_DIR}"

docker run --rm -it --init --cap-add NET_ADMIN --shm-size 2g \
  -v "$(cd "${OUTPUT_DIR}" && pwd):/output" \
  "${IMAGE}" bash
