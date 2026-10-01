# Autoware（公式ビルド済みイメージ）＋ scenario_simulator_v2 の実行用イメージ
#   作り方: scripts/setup.sh（Mac / Linux / WSL2 / Claude Code クラウド共通）
#
# ベースは動作確認済みの日付版に固定している（amd64 / arm64 両対応）。
# scenario_simulator_v2 のバージョンは、autowarefoundation/autoware の
# repositories/simulator.repos で指定されているものに合わせる。
ARG AUTOWARE_IMAGE=ghcr.io/autowarefoundation/autoware:universe-devel-humble-20260929
FROM ${AUTOWARE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root
ENV DEBIAN_FRONTEND=noninteractive

# ビルド中だけプロキシとその CA を使うためのヘルパー（CA はイメージに残さない）
COPY --chmod=755 docker/with-build-network.sh /usr/local/bin/with-build-network

# packages.ros.org に届かない環境向けに ROS の apt リポジトリをミラーへ差し替える（空なら変更しない）
ARG ROS_APT_MIRROR=""
RUN if [ -n "${ROS_APT_MIRROR}" ]; then \
      sed -i "s#http://packages.ros.org/ros2/ubuntu#${ROS_APT_MIRROR}#" /etc/apt/sources.list.d/ros2.sources; \
    fi

# 画面なしで RViz を動かす仮想ディスプレイ、ブラウザで画面を見るための VNC / noVNC、録画用の ffmpeg
RUN --mount=type=secret,id=proxy_ca \
    with-build-network bash -c "\
      apt-get update && \
      apt-get install -y --no-install-recommends xvfb x11vnc novnc python3-websockify ffmpeg && \
      rm -rf /var/lib/apt/lists/*" && \
    if [ ! -e /usr/share/novnc/index.html ]; then ln -s vnc.html /usr/share/novnc/index.html; fi

ARG SIM_VERSION=22.0.0
WORKDIR /aw_ws
RUN --mount=type=secret,id=proxy_ca \
    with-build-network git clone --depth 1 --branch "${SIM_VERSION}" \
      https://github.com/tier4/scenario_simulator_v2.git src/scenario_simulator_v2

RUN --mount=type=secret,id=proxy_ca \
    with-build-network bash -c "\
      source /opt/ros/humble/setup.bash && source /opt/autoware/setup.bash && \
      apt-get update && \
      rosdep update --rosdistro humble && \
      rosdep install -iy --from-paths src --rosdistro humble && \
      rm -rf /var/lib/apt/lists/*"

# build ディレクトリは BuildKit のキャッシュに置き、途中で失敗しても続きからビルドできるようにする。
# 実行時プラグイン（behavior_tree_plugin など）は依存関係に現れないので明示している。
# メモリ 8GB 程度でも落ちないよう、並列数は控えめ（BUILD_WORKERS × BUILD_JOBS）
ARG BUILD_WORKERS=2
ARG BUILD_JOBS=2
RUN --mount=type=secret,id=proxy_ca \
    --mount=type=cache,id=sandbox-autoware-sim-build,target=/aw_ws/build \
    with-build-network bash -c "\
      source /opt/ros/humble/setup.bash && source /opt/autoware/setup.bash && \
      MAKEFLAGS=-j${BUILD_JOBS} colcon build \
        --parallel-workers ${BUILD_WORKERS} \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
        --packages-up-to scenario_test_runner kashiwanoha_map openscenario_experimental_catalog \
          behavior_tree_plugin do_nothing_plugin real_time_factor_control_rviz_plugin && \
      rm -rf log"

# Autoware を RViz なしで起動するための小さな launch パッケージ（RViz は run_scenario が別に起動する）
COPY docker/sandbox_autoware_launch /aw_ws/src/sandbox_autoware_launch
RUN --mount=type=cache,id=sandbox-autoware-sim-build,target=/aw_ws/build \
    source /opt/ros/humble/setup.bash && source /opt/autoware/setup.bash && \
    colcon build --packages-select sandbox_autoware_launch && \
    rm -rf log

# `docker run -it <イメージ> bash` で入ったときに ROS / Autoware / シミュレーターを使えるようにする
RUN printf '%s\n' \
      'source /opt/ros/humble/setup.bash' \
      'source /opt/autoware/setup.bash' \
      'source /aw_ws/install/setup.bash' >> /root/.bashrc

COPY --chmod=755 docker/make_rviz_config.py /usr/local/bin/make_rviz_config
COPY --chmod=755 docker/run_scenario.sh /usr/local/bin/run_scenario

ENTRYPOINT []
CMD ["run_scenario"]
