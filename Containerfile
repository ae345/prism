# Prism: Bazzite (GNOME) をベースにした自作OSイメージ
#
# このPCは NVIDIA（RTX 3080）なので NVIDIA 版をベースにする。
# AMD / Intel の GPU なら ghcr.io/ublue-os/bazzite-gnome:stable に戻す
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable

# ビルド用スクリプトだけを入れておくステージ（最終イメージには残らない）
FROM scratch AS ctx
COPY build_files /

FROM ${BASE_IMAGE}

# /usr や /etc にそのまま置くファイル（見た目の設定、アシスタント本体など）
COPY system_files /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build.sh

# bootc のイメージとして問題がないかを確認する
RUN bootc container lint
