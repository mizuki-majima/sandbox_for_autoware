#!/bin/bash
# ホスト側で実行：Docker 起動 → Autoware イメージ取得 → シミュレーターのソース取得 → ビルド
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AW_WS="${AW_WS:-/home/user/aw_ws}"
IMAGE="${IMAGE:-ghcr.io/autowarefoundation/autoware:universe-devel-humble}"
# autowarefoundation/autoware の repositories/simulator.repos で指定されているバージョン
SIM_VERSION="${SIM_VERSION:-22.0.0}"
CONTAINER="${CONTAINER:-aw-sim}"

# Docker デーモンが動いていなければ起動
if ! docker info >/dev/null 2>&1; then
  echo "[setup] dockerd を起動します"
  nohup dockerd >/tmp/dockerd.log 2>&1 &
  for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi

echo "[setup] Autoware イメージを取得します: ${IMAGE}"
docker pull "${IMAGE}"

mkdir -p "${AW_WS}/src/simulator"
if [ ! -d "${AW_WS}/src/simulator/scenario_simulator" ]; then
  echo "[setup] scenario_simulator_v2 ${SIM_VERSION} を取得します"
  git clone --depth 1 --branch "${SIM_VERSION}" \
    https://github.com/tier4/scenario_simulator_v2.git "${AW_WS}/src/simulator/scenario_simulator"
fi

# ROS 2 (CycloneDDS) 向けのネットワーク設定
sysctl -w net.core.rmem_max=2147483647 net.ipv4.ipfrag_time=3 net.ipv4.ipfrag_high_thresh=134217728 >/dev/null

# クラウド環境のプロキシ用 CA があればコンテナに渡す
CA_MOUNT=()
if [ -f /root/.ccr/ca-bundle.crt ]; then
  CA_MOUNT=(-v /root/.ccr/ca-bundle.crt:/ca-bundle.crt:ro)
fi

docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
docker run -d --name "${CONTAINER}" --network host --shm-size=2g \
  -e HTTPS_PROXY="${HTTPS_PROXY}" -e https_proxy="${HTTPS_PROXY}" \
  -e NO_PROXY="${NO_PROXY}" -e no_proxy="${NO_PROXY}" \
  "${CA_MOUNT[@]}" \
  -v "${AW_WS}:/aw_ws" -v "${SCRIPT_DIR}:/scripts:ro" \
  --entrypoint sleep "${IMAGE}" infinity

# DDS がループバックでマルチキャストを使えるようにする
docker exec --privileged "${CONTAINER}" ip link set lo multicast on

echo "[setup] scenario_simulator_v2 をビルドします（30〜60分程度）"
docker exec "${CONTAINER}" bash /scripts/build_in_container.sh

echo "[setup] 完了しました。scripts/run.sh でシナリオを実行できます"
