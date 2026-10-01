#!/usr/bin/env python3
"""scenario_simulator_v2 同梱の RViz 設定を、仮想ディスプレイでの表示向けに書き換える。

    make_rviz_config.py <元の設定> <出力先> <幅x高さ> <light|full>

- ウィンドウの位置・サイズを仮想ディスプレイに合わせる（同梱の設定は大画面向けで、画面外に出てしまう）
- light: 自車・地図・経路・速度表示・シミュレーターの車両や信号だけを残し、点群やデバッグ表示を切る。
  ソフトウェア描画の RViz は、表示が多いと処理が追いつかず表示が止まって見えるため。
  （RViz の Displays パネルから、あとで個別に有効にできる）
  あわせて、上から見た視点のまま自車（base_link）を追いかけるようにする
- full: 表示の内容は変えない
"""
import sys

import yaml

# light で無効にする表示（グループ名をたどったパス）。設定にない名前は無視する
LIGHT_DISABLED = [
    ("System", "TF"),
    ("System", "Grid"),
    ("System", "MRM Summary"),
    ("Map", "Lanelet2VectorMap"),
    ("Sensing",),
    ("Localization",),
    ("Perception",),
    ("Planning", "ScenarioPlanning", "LaneDriving"),
    ("Planning", "ScenarioPlanning", "Parking"),
    ("Planning", "Diagnostic"),
    ("Control",),
    ("Debug",),
    ("Simulation", "Debug Marker"),
    ("Simulation", "Simple Sensor Simulator"),
]


def disable(displays, path):
    for display in displays or []:
        if display.get("Name") != path[0]:
            continue
        if len(path) == 1:
            display["Enabled"] = False
        else:
            disable(display.get("Displays"), path[1:])


def main():
    src, dst, size, view = sys.argv[1:5]
    width, height = (int(v) for v in size.split("x"))
    with open(src) as f:
        config = yaml.safe_load(f)

    geometry = config.setdefault("Window Geometry", {})
    geometry.update({"Width": width, "Height": height, "X": 0, "Y": 0})

    if view == "light":
        manager = config["Visualization Manager"]
        for path in LIGHT_DISABLED:
            disable(manager["Displays"], path)
        current_view = manager.get("Views", {}).get("Current", {})
        if current_view.get("Class") == "rviz_default_plugins/TopDownOrtho":
            current_view.update({"Target Frame": "base_link", "X": 0, "Y": 0})

    with open(dst, "w") as f:
        yaml.safe_dump(config, f, sort_keys=False, allow_unicode=True, width=1 << 20)


if __name__ == "__main__":
    main()
