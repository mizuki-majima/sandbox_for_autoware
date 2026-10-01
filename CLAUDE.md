# CLAUDE.md

TIER IV の scenario_simulator_v2 で Autoware を動かすサンドボックス。手順と仕組みは README.md を参照。

## クラウド環境（Claude Code on the web）でシミュレーションの実行を頼まれたら

- 前提：環境の Network access が `Full`（`ghcr.io` のイメージ本体が `pkg-containers.githubusercontent.com` から配信されるため）。足りなければ利用者に変更を頼む
- `scripts/setup.sh` を `run_in_background` で実行する（初回 約 45 分。dockerd の起動・プロキシ・CA・ROS ミラーはスクリプトが自動で処理する）
- `scripts/run.sh` を実行する（sample.yaml は 3 パターンで約 9 分）。終了コード 0 なら全シナリオ合格。合否だけ見たいなら `VIEWER=0`
- 結果は `output/<日時>/`：合否 `scenario_test_runner/result.junit.xml`、録画 `rviz.mp4`、ログ `launch.log`
- 利用者は録画を直接見られないので、`scripts/make_gif.sh <mp4> <開始秒> <長さ秒> <倍速> [幅]` で走行部分を GIF にして送る。
  走行区間は launch.log の `=> Driving` と `Passed` の時刻から見当をつけ、フレームを確認してから切り出す
- `output/` はコミットしない（.gitignore 済み）

## 変更するときの注意

- `scripts/*.sh` はホスト（macOS 標準の bash 3.2 を含む）で動く。連想配列・`${var,,}`・`mapfile`・`sed -i`・`readlink -f` など、bash 4 以降や GNU 独自の機能は使わない
- `docker/*.sh` はコンテナ内（Ubuntu 22.04 / bash 5）で動く
- ベースイメージ（Dockerfile の `AUTOWARE_IMAGE`）と `SIM_VERSION` は組み合わせで動作確認している。変えたらシナリオが通ることを確認する
- RViz の表示が止まる問題は CPU の取り合いが原因（README の「仕組みのメモ」参照）。RViz を Autoware 側で起動させる形に戻すと再発する
