#!/bin/bash
# docker build 中だけ、プロキシとその CA を使えるようにしてコマンドを実行する。
#   - CA は BuildKit の secret（id=proxy_ca）で受け取り、終わったら信頼ストアから外す
#   - プロキシは --build-arg HTTPS_PROXY などで渡された値を apt にも設定する
set -eo pipefail

ca_secret=/run/secrets/proxy_ca
ca_installed=/usr/local/share/ca-certificates/zz-build-proxy-ca.crt
apt_proxy_conf=/etc/apt/apt.conf.d/99build-proxy

cleanup() {
  rm -f "${apt_proxy_conf}"
  if [ -f "${ca_installed}" ]; then
    rm -f "${ca_installed}"
    update-ca-certificates --fresh >/dev/null
  fi
}
trap cleanup EXIT

if [ -s "${ca_secret}" ]; then
  cp "${ca_secret}" "${ca_installed}"
  update-ca-certificates >/dev/null
  # pip は独自の CA を使うため、システムの信頼ストアを使わせる
  export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
  export PIP_CERT=/etc/ssl/certs/ca-certificates.crt
fi

proxy="${HTTPS_PROXY:-${https_proxy:-}}"
if [ -n "${proxy}" ]; then
  echo "Acquire::https::Proxy \"${proxy}\";" > "${apt_proxy_conf}"
fi

"$@"
