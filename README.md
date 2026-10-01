# sandbox_for_autoware

TIER IV の [scenario_simulator_v2](https://github.com/tier4/scenario_simulator_v2) で Autoware を動かすためのサンドボックスです。
ローカルに Ubuntu PC がなくても、Claude Code のクラウド環境（Docker 使用）だけで
[QuickStart](https://tier4.github.io/scenario_simulator_v2-docs/user_guide/QuickStart/) の `scenario_test_runner`（`sample.yaml`）を実行できます。

## 動作確認結果

| 項目 | 結果 |
|---|---|
| 実行環境 | Claude Code クラウド環境（4 コア / メモリ 15GB / GPU なし） |
| シナリオ | `scenario_test_runner/scenario/sample.yaml`（開始レーン違いの 3 パターン） |
| 結果 | **3 / 3 Passed**（自車が Autoware の自動運転でゴールに到達） |

## 構成

| 要素 | 内容 |
|---|---|
| Autoware | 公式ビルド済みイメージ `ghcr.io/autowarefoundation/autoware:universe-devel-humble`（Ubuntu 22.04 / ROS 2 Humble、CUDA なし） |
| シミュレーター | scenario_simulator_v2 `22.0.0`（Autoware の `repositories/simulator.repos` 指定のバージョン）をイメージ上でビルド |
| 画面 | 仮想ディスプレイ（Xvfb）上で RViz を動かし、`ffmpeg` で録画 |

Autoware 本体はビルド済みイメージを使うため、Autoware のソースビルド（数時間）は不要です。

## 前提条件（クラウド環境の場合）

- 環境の **Network access を `Full`** にする（`Full` で動作確認済み）
  - 主な通信先：`ghcr.io` / `pkg-containers.githubusercontent.com`（Autoware イメージ）、
    `github.com` / `raw.githubusercontent.com`（ソース・rosdep）、`mirror.umd.edu`（ROS パッケージ）、`archive.ubuntu.com`
  - `packages.ros.org` は HTTP のみでプロキシを通らないため、公式ミラー `mirror.umd.edu`（HTTPS）に切り替えて使う
- ディスク空き 20GB 以上、メモリ 16GB 程度

## 使い方

```bash
# 1. 初回セットアップ（root で実行）
#    Docker 起動 → イメージ取得（約 5 分）→ シミュレーターのビルド（約 45 分）
scripts/setup.sh

# 2. シナリオ実行（3 パターンで約 7 分）
scripts/run.sh
```

結果は `/home/user/aw_ws/output/<日時>/` に保存されます。

| ファイル | 内容 |
|---|---|
| `scenario_test_runner/result.junit.xml` | シナリオの合否 |
| `rviz.mp4` | RViz 画面の録画 |
| `launch.log` | 実行ログ |

### オプション（環境変数）

| 変数 | 既定値 | 内容 |
|---|---|---|
| `SCENARIO` | `sample.yaml` | 実行するシナリオ（ファイル名だけなら同梱サンプルから探す） |
| `REAL_TIME_FACTOR` | `0.5` | シミュレーション速度。速いマシンなら `1.0` |
| `INITIALIZE_DURATION` | `300` | Autoware が発進待ちになるまでの待ち時間 [秒] |
| `GLOBAL_TIMEOUT` | `900` | 1 シナリオあたりの制限時間 [秒] |
| `SCREEN_SIZE` / `RECORD_FPS` | `1600x900` / `5` | 録画の画面サイズ・フレームレート |

例：`REAL_TIME_FACTOR=1.0 scripts/run.sh`

## 注意点

- クラウド環境はセッション終了で消えるため、新しいセッションでは `scripts/setup.sh` からやり直します。
- GPU がないため、センサー認識（LiDAR・カメラ）は動かしません。QuickStart と同じく、経路計画・制御のシミュレーション（planning simulator）です。
- RViz は録画を見る形で、マウス操作はできません。負荷が高いため、RViz の表示更新が止まって見える時間帯があります（合否はシミュレーター側で判定）。
- 4 コアのマシンでは Autoware の起動に 1 分前後かかるため、既定の待ち時間（30 秒）では `AutowareError`（発進待ちにならない）で失敗します。そのため `INITIALIZE_DURATION` を長くし、シミュレーション速度を半分にしています。

## つまずいた点と対処

| 症状 | 原因 | 対処 |
|---|---|---|
| `rosdep` / `apt` が失敗 | `packages.ros.org` が HTTP のみでプロキシ非対応 | ROS 公式ミラー（HTTPS）に切り替え |
| `embree_vendor` のビルドで git clone 失敗 | コンテナがプロキシの CA を信頼していない | CA をコンテナの信頼ストアに追加 |
| `behavior_tree_plugin/VehicleBehaviorTree does not exist` | 実行時プラグインが `--packages-up-to` の対象外 | `behavior_tree_plugin` などを明示してビルド |
| RViz が画面外に表示される | 同梱の RViz 設定が大画面向けの位置・サイズ | 画面サイズに合わせて書き換えた設定を `rviz_config` で渡す |
| RViz が 2 つ起動する | `launch_rviz:=true` だと Autoware 側と合わせて 2 つ起動 | `launch_rviz:=false`（Autoware 側の RViz だけ使う） |

## スクリプト一覧

| ファイル | 実行場所 | 役割 |
|---|---|---|
| `scripts/setup.sh` | ホスト | Docker 起動・イメージ取得・ソース取得・コンテナ作成・ビルド |
| `scripts/build_in_container.sh` | コンテナ | rosdep で依存関係を入れて colcon build |
| `scripts/run.sh` | ホスト | シナリオ実行（中で `run_in_container.sh` を呼ぶ） |
| `scripts/run_in_container.sh` | コンテナ | Xvfb＋録画しながら `scenario_test_runner` を起動 |
