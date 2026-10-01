#!/bin/bash
# Autoware 公式イメージの中で scenario_simulator_v2 をビルドする（コンテナ内で実行）
set -eo pipefail

ROS_APT_MIRROR="${ROS_APT_MIRROR:-https://mirror.umd.edu/packages.ros.org/ros2/ubuntu}"
BUILD_WORKERS="${BUILD_WORKERS:-2}"
BUILD_JOBS="${BUILD_JOBS:-2}"

cd /aw_ws

# プロキシ環境向け：apt / Python にプロキシと CA を設定
if [ -n "${HTTPS_PROXY}" ]; then
  echo "Acquire::https::Proxy \"${HTTPS_PROXY}\";" > /etc/apt/apt.conf.d/99proxy
fi
if [ -f /ca-bundle.crt ]; then
  # git / CMake のダウンロードもプロキシを通れるよう、システムの信頼ストアに追加
  cp /ca-bundle.crt /usr/local/share/ca-certificates/proxy-ca-bundle.crt
  update-ca-certificates >/dev/null
  echo 'Acquire::https::CaInfo "/ca-bundle.crt";' > /etc/apt/apt.conf.d/99ca
  export SSL_CERT_FILE=/ca-bundle.crt REQUESTS_CA_BUNDLE=/ca-bundle.crt
fi

# packages.ros.org に届かない環境向けに、公式ミラー（HTTPS）へ切り替え
sed -i "s#http://packages.ros.org/ros2/ubuntu#${ROS_APT_MIRROR}#" /etc/apt/sources.list.d/ros2.sources

apt-get update
# 画面なし環境で RViz を録画するための仮想ディスプレイ
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb

source /opt/ros/humble/setup.bash
source /opt/autoware/setup.bash

rosdep update --rosdistro humble
rosdep install -iy --from-paths src --rosdistro humble

# メモリ 16GB 程度でも落ちないよう並列数を抑えてビルド
export MAKEFLAGS="-j${BUILD_JOBS}"
colcon build --symlink-install \
  --parallel-workers "${BUILD_WORKERS}" \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
  --packages-up-to scenario_test_runner kashiwanoha_map openscenario_experimental_catalog \
    behavior_tree_plugin do_nothing_plugin real_time_factor_control_rviz_plugin
