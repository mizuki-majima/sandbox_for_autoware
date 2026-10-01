#!/bin/bash
# scenario_test_runner でシナリオを実行し、RViz の画面を録画する（コンテナ内で実行）
set -eo pipefail

SCENARIO="${SCENARIO:-sample.yaml}"
ARCHITECTURE_TYPE="${ARCHITECTURE_TYPE:-awf/universe/20250130}"
# 4 コア程度のマシンでも完走できるよう、待ち時間を長めに・シミュレーション速度を半分にしている
GLOBAL_TIMEOUT="${GLOBAL_TIMEOUT:-900}"            # 1 シナリオあたりの制限時間 [秒]
INITIALIZE_DURATION="${INITIALIZE_DURATION:-300}"  # Autoware が発進待ちになるまでの待ち時間 [秒]
REAL_TIME_FACTOR="${REAL_TIME_FACTOR:-0.5}"        # シミュレーション速度（1.0 = 実時間）
SCREEN_SIZE="${SCREEN_SIZE:-1600x900}"
RECORD_FPS="${RECORD_FPS:-5}"
OUT="/aw_ws/output/$(date +%Y%m%d_%H%M%S)"

mkdir -p "${OUT}"

source /opt/ros/humble/setup.bash
source /opt/autoware/setup.bash
source /aw_ws/install/setup.bash

# シナリオ名だけ渡されたら同梱サンプルから探す
if [ ! -f "${SCENARIO}" ]; then
  SCENARIO="$(ros2 pkg prefix --share scenario_test_runner)/scenario/${SCENARIO}"
fi

# RViz は Autoware 側（planning_simulator）が rviz_config を使って起動する。
# 同梱の RViz 設定は大画面向けの位置・サイズなので、仮想ディスプレイに収まるよう書き換える。
# （launch_rviz:=true にすると scenario_test_runner も RViz を起動し、2 つになるため false にしている）
RVIZ_CONFIG="${OUT}/scenario_simulator_v2.rviz"
python3 - "$(ros2 pkg prefix --share traffic_simulator)/config/scenario_simulator_v2.rviz" "${RVIZ_CONFIG}" "${SCREEN_SIZE}" <<'EOF'
import re, sys
src, dst, size = sys.argv[1:]
width, height = size.split("x")
text = open(src).read()
head, geometry = text.split("Window Geometry:", 1)
for key, value in (("Width", width), ("Height", height), ("X", "0"), ("Y", "0")):
    geometry = re.sub(rf"^  {key}: .*$", f"  {key}: {value}", geometry, flags=re.M)
open(dst, "w").write(head + "Window Geometry:" + geometry)
EOF

# 画面なし環境用の仮想ディスプレイ（GPU なしのソフトウェア描画）
export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
export LP_NUM_THREADS=2  # ソフトウェア描画のスレッド数を抑えて Autoware に CPU を回す
Xvfb :99 -screen 0 "${SCREEN_SIZE}x24" -nolisten tcp &
XVFB_PID=$!
sleep 2

# 仮想ディスプレイを録画
ffmpeg -loglevel error -y -f x11grab -video_size "${SCREEN_SIZE}" -framerate "${RECORD_FPS}" -i :99 \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p "${OUT}/rviz.mp4" &
FFMPEG_PID=$!

cleanup() {
  kill -INT "${FFMPEG_PID}" 2>/dev/null || true
  wait "${FFMPEG_PID}" 2>/dev/null || true
  kill "${XVFB_PID}" 2>/dev/null || true
}
trap cleanup EXIT

ros2 launch scenario_test_runner scenario_test_runner.launch.py \
  architecture_type:="${ARCHITECTURE_TYPE}" \
  record:=false \
  launch_rviz:=false \
  rviz_config:="${RVIZ_CONFIG}" \
  global_timeout:="${GLOBAL_TIMEOUT}" \
  initialize_duration:="${INITIALIZE_DURATION}" \
  global_real_time_factor:="${REAL_TIME_FACTOR}" \
  output_directory:="${OUT}" \
  scenario:="${SCENARIO}" \
  sensor_model:=sample_sensor_kit \
  vehicle_model:=sample_vehicle 2>&1 | tee "${OUT}/launch.log"

echo "結果の出力先: ${OUT}"
