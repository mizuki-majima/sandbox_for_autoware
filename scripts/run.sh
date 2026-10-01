#!/usr/bin/env bash
# シナリオを実行する（先に scripts/setup.sh でイメージを作っておく）。
#   - 実行中は http://localhost:6080 をブラウザで開くと画面（RViz）を見られる
#   - 合否・ログ・録画は output/<日時>/ に保存される
#   - 終了コード: 全シナリオ合格なら 0、それ以外は 0 以外
#
#   例) scripts/run.sh                          # 同梱の sample.yaml を実行
#       SCENARIO=path/to/my_scenario.yaml scripts/run.sh
#       REAL_TIME_FACTOR=1.0 scripts/run.sh     # 速いマシンなら実時間で
#
# 主な環境変数: SCENARIO, REAL_TIME_FACTOR, INITIALIZE_DURATION, GLOBAL_TIMEOUT, VIEWER, RVIZ_VIEW,
#               SIM_NICE, ARCHITECTURE_TYPE, SCREEN_SIZE, RECORD, RECORD_FPS, VIEWER_PORT, OUTPUT_DIR
set -eo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

detect_platform
ensure_docker
ensure_image

VIEWER_PORT="${VIEWER_PORT:-6080}"
mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"
RUN_ID="$(date +%Y%m%d_%H%M%S)"  # 結果フォルダ名（ホストの時刻）

# 手元のシナリオファイルが指定されたら、そのフォルダをコンテナに読み取り専用で渡す
scenario="${SCENARIO:-sample.yaml}"
scenario_args=()
if [ -f "${scenario}" ]; then
  scenario_dir="$(cd "$(dirname "${scenario}")" && pwd)"
  scenario_args=(-v "${scenario_dir}:/scenarios:ro")
  scenario="/scenarios/$(basename "${scenario}")"
fi

# 端末から実行したときは Ctrl+C で止められるようにする
tty_args=()
if [ -t 0 ] && [ -t 1 ]; then
  tty_args=(-it)
fi

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

log "シナリオを実行します"
if [ "${VIEWER:-1}" != "0" ]; then
  log "実行中は次の URL をブラウザで開くと画面（RViz）を見られます"
  log "  http://localhost:${VIEWER_PORT}/vnc.html?autoconnect=true&resize=scale"
fi

status=0
docker run --rm --init "${tty_args[@]}" --name "${CONTAINER_NAME}" \
  --cap-add NET_ADMIN --shm-size 2g \
  -p "127.0.0.1:${VIEWER_PORT}:6080" \
  -v "${OUTPUT_DIR}:/output" "${scenario_args[@]}" \
  -e SCENARIO="${scenario}" -e RUN_ID="${RUN_ID}" \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -e ARCHITECTURE_TYPE -e GLOBAL_TIMEOUT -e INITIALIZE_DURATION -e REAL_TIME_FACTOR \
  -e VIEWER -e SCREEN_SIZE -e RVIZ_VIEW -e SIM_NICE -e RECORD -e RECORD_FPS \
  "${IMAGE}" run_scenario || status=$?

if [ -d "${OUTPUT_DIR}/${RUN_ID}" ]; then
  log "結果の保存先: ${OUTPUT_DIR}/${RUN_ID}"
fi
exit "${status}"
