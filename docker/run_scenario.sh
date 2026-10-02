#!/bin/bash
# コンテナ内で実行：仮想ディスプレイ上で Autoware ＋ scenario_simulator_v2 のシナリオを動かす。
#   - 実行中の画面（RViz）は noVNC（ポート 6080）でブラウザから見られる
#   - 合否（junit）・ログ・録画は /output/<日時>/ に保存する
#   - 終了コード: 全シナリオ合格なら 0、それ以外は 1
set -eo pipefail

SCENARIO="${SCENARIO:-sample.yaml}"
ARCHITECTURE_TYPE="${ARCHITECTURE_TYPE:-awf/universe/20250130}"
# CPU 4 コア程度でも完走できるよう、待ち時間を長めに・シミュレーション速度を半分にしている
GLOBAL_TIMEOUT="${GLOBAL_TIMEOUT:-900}"            # 1 シナリオあたりの制限時間 [秒]
INITIALIZE_DURATION="${INITIALIZE_DURATION:-300}"  # Autoware が発進待ちになるまでの待ち時間 [秒]
REAL_TIME_FACTOR="${REAL_TIME_FACTOR:-0.5}"        # シミュレーション速度（1.0 = 実時間）
VIEWER="${VIEWER:-1}"                              # 0 なら RViz・ブラウザ表示・録画をせず、Autoware に CPU を全部回す
SCREEN_SIZE="${SCREEN_SIZE:-1600x900}"
RVIZ_VIEW="${RVIZ_VIEW:-light}"                    # light: 必要な表示だけ / full: Autoware の全表示（重い）
SIM_NICE="${SIM_NICE:-19}"                         # Autoware・シミュレーターの nice 値（RViz に CPU を回すため下げる）
RECORD="${RECORD:-1}"                              # 1 なら画面を録画する
RECORD_FPS="${RECORD_FPS:-5}"
if [ "${VIEWER}" = "0" ]; then
  RECORD=0
  SIM_NICE=0
fi
OUT="/output/${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"   # RUN_ID は run.sh がホストの時刻で付ける

log() { echo "[run_scenario] $*"; }

mkdir -p "${OUT}"

BACKGROUND_PIDS=()
cleanup() {
  if [ -n "${FFMPEG_PID:-}" ]; then
    kill -INT "${FFMPEG_PID}" 2>/dev/null || true
    wait "${FFMPEG_PID}" 2>/dev/null || true
  fi
  for pid in "${BACKGROUND_PIDS[@]}"; do
    kill "${pid}" 2>/dev/null || true
  done
  pkill -x rviz2 2>/dev/null || true
  # ホストのユーザーで結果を開けるよう、所有者を合わせる
  if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
    chown -R "${HOST_UID}:${HOST_GID}" "${OUT}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

source /opt/ros/humble/setup.bash
source /opt/autoware/setup.bash
source /aw_ws/install/setup.bash

# シナリオ名だけ渡されたら同梱サンプルから探す
if [ ! -f "${SCENARIO}" ]; then
  SCENARIO="$(ros2 pkg prefix --share scenario_test_runner)/scenario/${SCENARIO}"
fi
[ -f "${SCENARIO}" ] || { log "ERROR: シナリオが見つかりません: ${SCENARIO}"; exit 1; }

# --- ROS 2（CycloneDDS）の通信設定 ---
# Autoware の設定はループバックのマルチキャストで通信相手を見つける（docker run --cap-add NET_ADMIN が必要）
if ! ip link set lo multicast on 2>/dev/null && ! ip link show lo | grep -q MULTICAST; then
  log "ERROR: ループバックのマルチキャストを有効にできません（docker run に --cap-add NET_ADMIN が必要です）"
  exit 1
fi
# Autoware の設定は受信バッファ 10MB 以上を要求し、OS の上限（net.core.rmem_max）が足りないとノードが起動できない。
# 上限を上げられない環境（Docker Desktop など）では、この要求だけを外した設定を使う
#（sysctl は設定に失敗しても終了コード 0 を返すことがあるので、設定後の値を読み直して判断する）
rmem_max="$(cat /proc/sys/net/core/rmem_max 2>/dev/null || echo 0)"
if [ "${rmem_max}" -lt 10485760 ]; then
  sysctl -qw net.core.rmem_max=2147483647 >/dev/null 2>&1 || true
  rmem_max="$(cat /proc/sys/net/core/rmem_max 2>/dev/null || echo 0)"
fi
if [ "${rmem_max}" -lt 10485760 ]; then
  sed '/SocketReceiveBufferSize/d' "${CYCLONEDDS_URI#file://}" > /tmp/cyclonedds.xml
  export CYCLONEDDS_URI="file:///tmp/cyclonedds.xml"
  log "受信バッファの上限が ${rmem_max} バイトのため、CycloneDDS の受信バッファ要求を外して実行します"
fi

if [ "${VIEWER}" = "1" ]; then
  # --- RViz の設定 ---
  # 同梱の設定を、仮想ディスプレイのサイズに合わせ、RVIZ_VIEW=light なら表示を軽くして使う（make_rviz_config.py 参照）
  RVIZ_CONFIG="${OUT}/scenario_simulator_v2.rviz"
  make_rviz_config "$(ros2 pkg prefix --share traffic_simulator)/config/scenario_simulator_v2.rviz" \
    "${RVIZ_CONFIG}" "${SCREEN_SIZE}" "${RVIZ_VIEW}"

  # --- 仮想ディスプレイと、ブラウザで見るための VNC / noVNC ---
  export DISPLAY=:99
  export LIBGL_ALWAYS_SOFTWARE=1                # GPU なしのソフトウェア描画
  export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"  # ソフトウェア描画のスレッド数
  Xvfb :99 -screen 0 "${SCREEN_SIZE}x24" -nolisten tcp >/tmp/xvfb.log 2>&1 &
  BACKGROUND_PIDS+=($!)
  for _ in $(seq 1 50); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.1; done
  x11vnc -display :99 -forever -shared -nopw -localhost -rfbport 5900 -quiet >/tmp/x11vnc.log 2>&1 &
  BACKGROUND_PIDS+=($!)
  websockify --web /usr/share/novnc 6080 localhost:5900 >/tmp/novnc.log 2>&1 &
  BACKGROUND_PIDS+=($!)

  if [ "${RECORD}" = "1" ]; then
    ffmpeg -loglevel error -y -f x11grab -video_size "${SCREEN_SIZE}" -framerate "${RECORD_FPS}" -i :99 \
      -c:v libx264 -preset ultrafast -pix_fmt yuv420p "${OUT}/rviz.mp4" &
    FFMPEG_PID=$!
  fi

  # --- RViz ---
  # RViz はここで 1 つだけ起動し、全シナリオの間そのまま使う。
  # ソフトウェア描画の RViz は CPU を多く使い、Autoware に CPU を取られるとメッセージを処理できず表示が止まる。
  # そのため RViz は通常の優先度で動かし、Autoware・シミュレーターは nice 値（SIM_NICE）を上げて優先度を下げる。
  # （Autoware 側の RViz は sandbox_autoware_launch で止め、scenario_test_runner 側も launch_rviz:=false にしている）
  # RViz が途中で終了しても、シナリオの間は起動し直す（ログは rviz.log に残す）
  (
    while true; do
      rviz2 -d "${RVIZ_CONFIG}" -s "" >>"${OUT}/rviz.log" 2>&1 || true
      echo "[run_scenario] RViz が終了したため起動し直します" >>"${OUT}/rviz.log"
      sleep 2
    done
  ) &
  BACKGROUND_PIDS+=($!)
fi

# --- シナリオ実行 ---
# docker stop / Ctrl+C を受けたら ros2 launch に伝えて、きれいに終了させる
nice -n "${SIM_NICE}" ros2 launch scenario_test_runner scenario_test_runner.launch.py \
  architecture_type:="${ARCHITECTURE_TYPE}" \
  autoware_launch_package:=sandbox_autoware_launch \
  autoware_launch_file:=planning_simulator.launch.xml \
  record:=false \
  launch_rviz:=false \
  global_timeout:="${GLOBAL_TIMEOUT}" \
  initialize_duration:="${INITIALIZE_DURATION}" \
  global_real_time_factor:="${REAL_TIME_FACTOR}" \
  output_directory:="${OUT}" \
  scenario:="${SCENARIO}" \
  sensor_model:=sample_sensor_kit \
  vehicle_model:=sample_vehicle > >(tee "${OUT}/launch.log") 2>&1 &
LAUNCH_PID=$!
trap 'kill -TERM "${LAUNCH_PID}" 2>/dev/null || true' INT TERM
wait "${LAUNCH_PID}" || true
wait "${LAUNCH_PID}" 2>/dev/null || true

# --- 結果のまとめ ---
JUNIT="${OUT}/scenario_test_runner/result.junit.xml"
if [ ! -f "${JUNIT}" ]; then
  log "ERROR: 結果ファイルがありません（${JUNIT}）。launch.log を確認してください"
  exit 1
fi
python3 - "${JUNIT}" <<'EOF'
import sys
import xml.etree.ElementTree as ET

cases = ET.parse(sys.argv[1]).getroot().findall(".//testcase")
failed = []
for case in cases:
    problem = case.find("failure")
    if problem is None:
        problem = case.find("error")
    if problem is not None:
        failed.append((case.get("name"), problem.get("type"), problem.get("message")))
print(f"[run_scenario] 結果: {len(cases) - len(failed)} / {len(cases)} 合格")
for name, kind, message in failed:
    print(f"[run_scenario]   NG {name}: {kind}: {message}")
sys.exit(1 if failed or not cases else 0)
EOF
