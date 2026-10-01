#!/bin/bash
# ホスト側で実行：シナリオを実行して結果と録画を output/ に保存する
#   例) scripts/run.sh                       # 同梱の sample.yaml を実行
#       SCENARIO=xxx.yaml scripts/run.sh
#       REAL_TIME_FACTOR=1.0 scripts/run.sh  # 速いマシンなら実時間で
set -eo pipefail

CONTAINER="${CONTAINER:-aw-sim}"

# 指定された環境変数だけコンテナに渡す（未指定ならコンテナ側の既定値）
docker exec \
  -e SCENARIO -e ARCHITECTURE_TYPE -e GLOBAL_TIMEOUT -e INITIALIZE_DURATION \
  -e REAL_TIME_FACTOR -e SCREEN_SIZE -e RECORD_FPS \
  "${CONTAINER}" bash /scripts/run_in_container.sh
