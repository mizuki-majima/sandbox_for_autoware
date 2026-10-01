# sandbox_for_autoware

TIER IV の [scenario_simulator_v2](https://github.com/tier4/scenario_simulator_v2) で Autoware を動かすためのサンドボックスです。
**Mac・Linux・Windows（WSL2）・Claude Code のクラウド環境のどれでも、同じ 2 つのコマンド**で
[QuickStart](https://tier4.github.io/scenario_simulator_v2-docs/user_guide/QuickStart/) のサンプルシナリオを実行できます。

```bash
scripts/setup.sh   # 初回だけ：実行用の Docker イメージを作る（30〜60 分）
scripts/run.sh     # シナリオを実行（3 パターンで約 9 分）
```

- 実行中は **ブラウザで http://localhost:6080 を開くと、RViz の画面をリアルタイムで見られます**（マウス操作も可）
- 合否・ログ・録画（mp4）は `output/<日時>/` に保存されます

## 必要なもの

| 環境 | 用意するもの |
|---|---|
| Mac（Apple Silicon / Intel） | [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/)。Settings → Resources で **CPU 4 コア以上・メモリ 8GB 以上**、ディスク空き 30GB 以上 |
| Linux | Docker Engine（buildx 入り）。ディスク空き 30GB 以上 |
| Windows | WSL2 の Ubuntu ＋ Docker Desktop（Settings → Resources → WSL integration で Ubuntu を有効化）。コマンドは **WSL2 の Ubuntu ターミナル**で実行 |
| Claude Code のクラウド環境 | 環境の **Network access を `Full`** にする（Docker は自動で起動） |

> Docker Desktop は、従業員 250 人以上または年間売上 1,000 万ドル以上の企業で業務に使う場合、有料サブスクリプションが必要です。会社の PC で使う場合は社内ルールを確認してください。

GPU は不要です（センサー認識を使わない planning simulator 構成のため）。

## 使い方

```bash
git clone https://github.com/mizuki-majima/sandbox_for_autoware.git
cd sandbox_for_autoware

scripts/setup.sh   # 初回だけ
scripts/run.sh
```

`run.sh` を実行したら、ブラウザで次を開きます。Autoware が起動して走り出すまで 1〜2 分かかります。

```
http://localhost:6080/vnc.html?autoconnect=true&resize=scale
```

終了すると、結果が次のように表示されます。

```
[run_scenario] 結果: 3 / 3 合格
[run.sh] 結果の保存先: .../output/20261001_174441
```

| 保存されるファイル | 内容 |
|---|---|
| `scenario_test_runner/result.junit.xml` | シナリオごとの合否 |
| `rviz.mp4` | RViz 画面の録画 |
| `launch.log` | 実行ログ |

録画の一部を GIF にする（共有用）：

```bash
scripts/make_gif.sh output/<日時>/rviz.mp4 80 115 4   # 80 秒目から 115 秒分を 4 倍速で
```

### オプション（環境変数）

| 変数 | 既定値 | 内容 |
|---|---|---|
| `SCENARIO` | `sample.yaml` | 実行するシナリオ。手元のファイルのパスも指定できる |
| `VIEWER` | `1` | `0` にすると RViz・ブラウザ表示・録画をせず、Autoware に CPU を全部回す（合否だけ見たいとき） |
| `RVIZ_VIEW` | `light` | `light`: 自車・地図・経路・速度表示などに絞った軽い表示 / `full`: Autoware の全表示（重い） |
| `REAL_TIME_FACTOR` | `0.5` | シミュレーション速度。速いマシンなら `1.0` |
| `SIM_NICE` | `19` | Autoware・シミュレーターの nice 値（RViz に CPU を回すため優先度を下げる）。`0` で同じ優先度 |
| `INITIALIZE_DURATION` | `300` | Autoware が発進待ちになるまでの待ち時間 [秒] |
| `GLOBAL_TIMEOUT` | `900` | 1 シナリオあたりの制限時間 [秒] |
| `VIEWER_PORT` | `6080` | ブラウザで見るためのポート |
| `SCREEN_SIZE` / `RECORD_FPS` | `1600x900` / `5` | 画面サイズ・録画のフレームレート |
| `RECORD` | `1` | `0` にすると録画しない |
| `BUILD_JOBS` | `2` | （setup.sh）ビルドの並列数。メモリ不足で落ちるなら `1` |

例：`REAL_TIME_FACTOR=1.0 scripts/run.sh`、`VIEWER=0 scripts/run.sh`

## 構成

| 要素 | 内容 |
|---|---|
| Autoware | 公式ビルド済みイメージ `ghcr.io/autowarefoundation/autoware:universe-devel-humble-20260929`（動作確認済みの日付版に固定。amd64 / arm64 両対応、CUDA なし） |
| シミュレーター | scenario_simulator_v2 `22.0.0`（Autoware の `repositories/simulator.repos` 指定のバージョン）をイメージ内でビルド |
| 画面 | 仮想ディスプレイ（Xvfb）上で RViz を動かし、noVNC でブラウザに表示・ffmpeg で録画 |

| ファイル | 役割 |
|---|---|
| `docker/Dockerfile` | 実行用イメージの定義 |
| `docker/run_scenario.sh` | コンテナ内でシナリオを実行（通信設定・画面表示・録画・結果まとめ） |
| `docker/make_rviz_config.py` | RViz の設定を画面サイズに合わせ、`light` 表示に絞る |
| `docker/sandbox_autoware_launch/` | Autoware を RViz なしで起動する launch（RViz は run_scenario が別に起動） |
| `docker/with-build-network.sh` | ビルド中だけプロキシ・CA を使うヘルパー |
| `scripts/setup.sh` / `scripts/run.sh` | イメージ作成 / シナリオ実行 |
| `scripts/make_gif.sh` / `scripts/shell.sh` | 録画の GIF 化 / イメージ内でシェルを開く（調査用） |

## 動作確認状況

| 環境 | 状況 |
|---|---|
| Claude Code のクラウド環境（Linux / amd64、4 コア・メモリ 15GB） | `setup.sh`（約 45 分）→ `run.sh`（約 9 分）で **3 / 3 合格**。ブラウザ表示がリアルタイムに更新されることも確認 |
| Mac（Apple Silicon） | 未確認（arm64 版の Autoware イメージ、scenario_simulator_v2 の arm64 対応、スクリプトの macOS 標準 bash 3.2 での動作は確認済み） |
| Linux PC / Windows（WSL2） | 未確認 |

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| `setup.sh` がメモリ不足（`Killed` など）で失敗 | `BUILD_JOBS=1 scripts/setup.sh`（途中から再開されます） |
| `AutowareError: ... WAITING_FOR_ENGAGE` で失敗 | マシンが遅い。`INITIALIZE_DURATION=600 REAL_TIME_FACTOR=0.3 scripts/run.sh` |
| ブラウザの表示（速度・自車）が更新されない | CPU 不足。Docker Desktop の CPU を増やす。それでも遅いときは `SCREEN_SIZE=1280x720` |
| ポート 6080 が使用中 | `VIEWER_PORT=6081 scripts/run.sh` |
| 社内プロキシの内側でビルドできない | `HTTPS_PROXY` を設定し、TLS を検査するプロキシなら `PROXY_CA_CERT=/path/to/ca.crt` も指定 |
| ディスクを空けたい | `docker image rm sandbox-autoware-sim ghcr.io/autowarefoundation/autoware:universe-devel-humble-20260929` と `docker builder prune` |

## 仕組みのメモ（つまずいた点）

| 症状 | 原因 | 対処 |
|---|---|---|
| ROS のノードが起動しない（`failed to increase socket receive buffer size`） | Autoware の CycloneDDS 設定は受信バッファ 10MB 以上を要求するが、Docker Desktop などでは OS の上限を上げられない | 上限が足りないときは、その要求だけを外した設定で実行 |
| ノード同士が通信できない | CycloneDDS はループバックのマルチキャストで相手を探す | `--cap-add NET_ADMIN` を付けてコンテナ内で有効化 |
| `behavior_tree_plugin/VehicleBehaviorTree does not exist` | 実行時プラグインが依存関係に現れない | ビルド対象に明示 |
| RViz の表示（速度・自車）が止まったまま | RViz は描画の合間に 10ms だけメッセージを処理する作り。ソフトウェア描画で CPU を Autoware に取られると、ほとんど処理できない | RViz を 1 つだけ通常の優先度で起動し、Autoware・シミュレーターは nice 19 で動かす。表示も `light` に絞る |
| RViz が画面外に出る | 同梱の RViz 設定が大画面向けの位置・サイズ | 画面サイズに合わせて書き換える |
| `AutowareError`（発進待ちにならない） | 4 コアでは Autoware の起動に 1 分前後かかり、既定の待ち時間 30 秒では足りない | 待ち時間を延ばし、シミュレーション速度を半分に |
| クラウド環境で `rosdep` / `apt` が失敗 | `packages.ros.org` が HTTP のみでプロキシを通らない | クラウド環境では ROS 公式ミラー（HTTPS）を自動で使う |
