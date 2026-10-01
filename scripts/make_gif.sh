#!/usr/bin/env bash
# 録画（mp4）の一部を GIF にする。ffmpeg はイメージの中のものを使うので、手元に入れなくてよい。
#   使い方: scripts/make_gif.sh <mp4 ファイル> [開始秒=0] [長さ秒=60] [倍速=3] [幅=720]
#   例)     scripts/make_gif.sh output/20261001_174441/rviz.mp4 80 115 4
set -eo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

[ -f "${1:-}" ] || die "使い方: scripts/make_gif.sh <mp4 ファイル> [開始秒=0] [長さ秒=60] [倍速=3] [幅=720]"
detect_platform
ensure_docker
ensure_image

input_dir="$(cd "$(dirname "$1")" && pwd)"
input_file="$(basename "$1")"
start="${2:-0}"
duration="${3:-60}"
speed="${4:-3}"
width="${5:-720}"
output_file="${input_file%.*}_${start}s.gif"

docker run --rm --user "$(id -u):$(id -g)" -v "${input_dir}:/work" -w /work "${IMAGE}" \
  ffmpeg -loglevel error -y -ss "${start}" -t "${duration}" -i "${input_file}" \
  -vf "setpts=PTS/${speed},fps=6,scale=${width}:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer" \
  "${output_file}"

log "作成しました: ${input_dir}/${output_file}"
