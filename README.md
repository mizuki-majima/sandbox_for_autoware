# sandbox_for_autoware

TIER IV の [scenario_simulator_v2](https://github.com/tier4/scenario_simulator_v2) で Autoware を動かすためのサンドボックスです。
**Windows・Mac・Linux・Claude Code のクラウド環境のどれでも、Docker さえあれば同じ 2 ステップ**で
[QuickStart](https://tier4.github.io/scenario_simulator_v2-docs/user_guide/QuickStart/) のサンプルシナリオを実行できます。

| | Windows | Mac / Linux |
|---|---|---|
| 1. 準備（初回だけ・30〜60 分） | `scripts\setup.cmd` | `scripts/setup.sh` |
| 2. シナリオ実行（3 パターンで約 10 分） | `scripts\run.cmd` | `scripts/run.sh` |

- 実行中は **ブラウザで http://localhost:6080 を開くと、RViz の画面をリアルタイムで見られます**（マウス操作も可）
- 合否・ログ・録画（mp4）は `output/<日時>/` に保存されます
- GPU は不要です（センサー認識を使わない planning simulator 構成のため）

## 1. 必要なもの

| PC | 用意するもの |
|---|---|
| Windows 10 / 11 | [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/)（初期設定の WSL2 方式でよい） |
| Mac（Apple Silicon / Intel） | [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/) |
| Linux | [Docker Engine](https://docs.docker.com/engine/install/)（buildx 入り） |
| Claude Code のクラウド環境 | 環境の **Network access を `Full`** にする（Docker は自動で起動） |

どの PC でも、Docker に **CPU 4 コア以上・メモリ 8GB 以上・ディスク空き 30GB 以上** を割り当ててください。

- Mac：Docker Desktop の Settings → Resources で設定
- Windows：初期設定では PC のメモリの半分・全 CPU が使われます。足りないときは `%UserProfile%\.wslconfig` に次を書き、PowerShell で `wsl --shutdown` を実行してから Docker Desktop を起動し直します

  ```ini
  [wsl2]
  memory=8GB
  processors=4
  ```

> Docker Desktop は、従業員 250 人以上または年間売上 1,000 万ドル以上の企業で業務に使う場合、有料サブスクリプションが必要です。会社の PC で使う場合は社内ルールを確認してください。

## 2. ダウンロード

Git がある場合：

```bash
git clone https://github.com/mizuki-majima/sandbox_for_autoware.git
cd sandbox_for_autoware
```

Git がない場合：GitHub のページで **Code → Download ZIP** を押し、展開したフォルダを使います。

## 3. 実行

### Windows

Docker Desktop を起動しておき、PowerShell（またはコマンドプロンプト）で、ダウンロードしたフォルダに移動して実行します（`setup.cmd` は初回だけ）。
エクスプローラーで `scripts` フォルダの `setup.cmd` → `run.cmd` を順にダブルクリックしても動きます。

```powershell
cd sandbox_for_autoware
scripts\setup.cmd
scripts\run.cmd
```

### Mac / Linux

Docker Desktop（Linux は Docker）を起動しておき、ターミナルで実行します。

```bash
cd sandbox_for_autoware
scripts/setup.sh    # 初回だけ
scripts/run.sh
```

ZIP で取ってきて `Permission denied` と出るときは、`bash scripts/setup.sh` のように `bash` を付けて実行します。

### Claude Code のクラウド環境

このリポジトリでセッションを開き、「`scripts/setup.sh` と `scripts/run.sh` を実行して、録画を GIF で見せて」と頼みます（手順は CLAUDE.md に記載）。

### 実行中・実行後

`run` を実行したら、ブラウザで次を開きます。Autoware が起動して走り出すまで 1〜2 分かかります。

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
| `rviz.log` | RViz のログ（表示がおかしいときの調査用） |
| `launch.log` | 実行ログ |

録画の一部を GIF にする（共有用。例は 80 秒目から 115 秒分を 4 倍速で）：

```bash
scripts/make_gif.sh output/<日時>/rviz.mp4 80 115 4      # Mac / Linux
scripts\make_gif.cmd output\<日時>\rviz.mp4 80 115 4     # Windows
```

## 4. ほかのシナリオを動かす

`SCENARIO` にシナリオ名（同梱のもの）か、手元の YAML ファイルのパス（自作のもの）を指定します。

```bash
SCENARIO=RoutingAction.AcquirePositionAction-continuous.yaml scripts/run.sh          # Mac / Linux
$env:SCENARIO = 'RoutingAction.AcquirePositionAction-continuous.yaml'; scripts\run.cmd   # Windows（PowerShell）
SCENARIO=path/to/my_scenario.yaml scripts/run.sh                                      # 自作のシナリオ
```

scenario_simulator_v2 には 78 本のシナリオが同梱されていますが、多くはシミュレーター自体の機能テストで、
**Autoware が運転するのは 25 本**です（うち 3 本は別の 3D シミュレーター AWSIM 用で、この環境では使えません）。主なもの：

| 種類 | `SCENARIO` | 内容 | この環境での確認 |
|---|---|---|---|
| 基本 | `sample.yaml` | 3 つの開始位置からゴールまで走る | ✅ 合格（約 10 分） |
| 連続ゴール | `RoutingAction.AcquirePositionAction-continuous.yaml` | ゴールに着くたびに次のゴールへ（6 回） | ✅ 合格（約 15 分） |
| ゴール変更 | `RoutingAction.AcquirePositionAction-allow_goal_modification.yaml` | 走り出した直後に別の車がゴールに止まり、Autoware がゴールをずらして停車 | ✅ 7 回中 6 回合格（※） |
| 認識の欠落 | `Property.detectedObjectMissingProbability.yaml` | 前を走る遅い車の認識が 7 割欠ける状態で、ぶつからずに走りきれるか | ✅ 合格（約 4 分） |
| 認識の遅れ・誤差 | `Property.detectedObjectPublishingDelay.yaml`、`Property.detectedObjectPositionStandardDeviation.yaml`、`Property.detectionSensorRange.yaml` など | 認識結果の遅れ・位置のばらつき・見える距離を変える | 未確認 |
| 経路の指定 | `RoutingAction.AssignRouteAction.yaml` | 経由地を指定して走る | 未確認 |
| 故障の注入 | `CustomCommandAction.FaultInjectionAction.yaml` | Autoware に故障を知らせたときの振る舞い | 未確認 |
| 信号の認識 | `CustomCommandAction.PseudoTrafficSignalDetectorConfidenceSetAction@v1.yaml` | 信号の認識の確からしさを変える | 未確認 |

※ ゴールが変わってルートが切り替わる瞬間に、Autoware の経路計画プロセスがまれに異常終了することがあります（`guard condition implementation is invalid`。ROS 2 のタイミングの問題で、CPU が少ないと起きやすい）。失敗したら再実行してください。

同梱シナリオの一覧はコンテナの中で確認できます（`scripts/shell.sh` で入って `ls /aw_ws/install/scenario_test_runner/share/scenario_test_runner/scenario`）。
シナリオの書き方は [scenario_simulator_v2 のドキュメント](https://tier4.github.io/scenario_simulator_v2-docs/) を参照してください。

## 5. オプション（環境変数）

指定のしかた：

| シェル | 例 |
|---|---|
| Mac / Linux | `VIEWER=0 scripts/run.sh` |
| Windows（PowerShell） | `$env:VIEWER = '0'; scripts\run.cmd` |
| Windows（コマンドプロンプト） | `set VIEWER=0` のあとに `scripts\run.cmd` |

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
| `BUILD_JOBS` | `2` | （setup）ビルドの並列数。メモリ不足で落ちるなら `1` |
| `HTTPS_PROXY` / `PROXY_CA_CERT` | なし | （setup）社内プロキシと、その CA 証明書（下記） |

## 6. トラブルシューティング

| 症状 | 対処 |
|---|---|
| `docker コマンドがありません` / `Docker に接続できません` | Docker Desktop をインストール・起動し、「Engine running」になってから再実行 |
| `Windows コンテナのモードです` | タスクトレイの Docker アイコンを右クリック →「Switch to Linux containers」 |
| setup がメモリ不足（`Killed` など）で失敗 | `BUILD_JOBS=1` を指定して再実行（途中から再開されます） |
| `AutowareError: ... WAITING_FOR_ENGAGE` で失敗 | マシンが遅い。`INITIALIZE_DURATION=600`・`REAL_TIME_FACTOR=0.3` を指定 |
| ブラウザの表示（速度・自車）が更新されない・遅れる | CPU 不足。Docker の CPU 割り当てを増やす。それでも遅いときは `SCREEN_SIZE=1280x720`（車の動きは見えるが、速度などの数字は遅れることがある） |
| ポート 6080 が使用中 | `VIEWER_PORT=6081` を指定し、ブラウザも 6081 で開く |
| 社内プロキシの内側でビルドできない | Docker Desktop の Settings → Resources → Proxies を設定し、`HTTPS_PROXY`・`HTTP_PROXY` も指定。TLS を検査するプロキシなら、その CA 証明書（PEM 形式。Windows の「Base 64 encoded X.509 (.CER)」で書き出したもの）を `PROXY_CA_CERT` に指定 |
| Windows で「このシステムではスクリプトの実行が無効」と出る | `.ps1` を直接実行せず、`scripts\setup.cmd` / `scripts\run.cmd` を使う。会社のポリシーで PowerShell が使えない場合は、WSL2 の Ubuntu で Mac / Linux の手順を使う |
| Windows の Git Bash で実行した | Git Bash では動きません。`scripts\setup.cmd` / `scripts\run.cmd` を使う |
| setup で `universe-devel-humble-20260929: not found` と出る | 固定している Autoware の日付版イメージが公開終了した。`AUTOWARE_IMAGE` に新しい日付版（例 `ghcr.io/autowarefoundation/autoware:universe-devel-humble-20261101`）を、`SIM_VERSION` にその時点の [simulator.repos](https://github.com/autowarefoundation/autoware/blob/main/repositories/simulator.repos) のバージョンを指定 |
| ディスクを空けたい | `docker image rm sandbox-autoware-sim ghcr.io/autowarefoundation/autoware:universe-devel-humble-20260929` と `docker builder prune` |

## 7. 動作確認状況

| 環境 | 状況 |
|---|---|
| Claude Code のクラウド環境（Linux / amd64、4 コア・メモリ 15GB） | Docker を空にし、GitHub から取得したばかりの状態で確認。`setup.ps1`（PowerShell 版）で一からイメージ作成（約 44 分）→ `setup.sh` はキャッシュで 2 秒。`run.ps1`・`run.sh` ともに **3 / 3 合格**（各 約 11 分）、ブラウザ表示のリアルタイム更新、`make_gif` も確認。実行中のメモリ使用量は最大 約 2GB |
| Windows | 実機は未確認。PowerShell 版スクリプト自体は上記で動作確認済みで、Windows PowerShell 5.1 との互換性の静的検査（PSScriptAnalyzer）と、Windows を想定した分岐（Windows コンテナモードの検出・プロキシの読み替えなど）の模擬テストも済み |
| Mac（Apple Silicon） | 未確認（arm64 版の Autoware イメージ、scenario_simulator_v2 の arm64 対応、macOS 標準の bash 3.2 での動作は確認済み） |
| Linux PC | クラウド環境と同じ Linux なので、Docker があれば同様に動く見込み |

## 8. 構成

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
| `scripts/*.sh` | Mac / Linux 用（macOS 標準の bash 3.2 でも動く） |
| `scripts/*.cmd`・`scripts/*.ps1` | Windows 用（`.cmd` が入口で、中から PowerShell 5.1 互換の `.ps1` を呼ぶ） |

## 9. 仕組みのメモ（つまずいた点）

| 症状 | 原因 | 対処 |
|---|---|---|
| ROS のノードが起動しない（`failed to increase socket receive buffer size`） | Autoware の CycloneDDS 設定は受信バッファ 10MB 以上を要求するが、Docker Desktop などでは OS の上限を上げられない | 上限が足りないときは、その要求だけを外した設定で実行 |
| ノード同士が通信できない | CycloneDDS はループバックのマルチキャストで相手を探す | `--cap-add NET_ADMIN` を付けてコンテナ内で有効化 |
| `behavior_tree_plugin/VehicleBehaviorTree does not exist` | 実行時プラグインが依存関係に現れない | ビルド対象に明示 |
| RViz の表示（速度・自車）が止まったまま | RViz は描画の合間に 10ms だけメッセージを処理する作り。ソフトウェア描画で CPU を Autoware に取られると、ほとんど処理できない | RViz を 1 つだけ通常の優先度で起動し、Autoware・シミュレーターは nice 19 で動かす。表示も `light` に絞る |
| RViz が画面外に出る | 同梱の RViz 設定が大画面向けの位置・サイズ | 画面サイズに合わせて書き換える |
| `AutowareError`（発進待ちにならない） | 4 コアでは Autoware の起動に 1 分前後かかり、既定の待ち時間 30 秒では足りない | 待ち時間を延ばし、シミュレーション速度を半分に |
| Windows で clone すると bash スクリプトが動かない | Git for Windows が改行を CRLF に変える | `.gitattributes` で LF に固定し、イメージ内でも念のため LF にそろえる |
| クラウド環境で `rosdep` / `apt` が失敗 | `packages.ros.org` が HTTP のみでプロキシを通らない | クラウド環境では ROS 公式ミラー（HTTPS）を自動で使う |
